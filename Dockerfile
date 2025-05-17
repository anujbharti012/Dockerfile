FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV TZ=UTC
ENV PORT=8080

# Update and install core packages
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y sudo curl ffmpeg git locales nano python3-pip python3-dev python3-venv \
    build-essential libssl-dev libffi-dev screen ssh unzip wget tzdata \
    python3-numpy python3-pandas python3-matplotlib python3-scipy python3-sklearn \
    python3-tk python3-setuptools python3-wheel && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
    curl -sL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs && \
    pip3 install --upgrade pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install data science and machine learning packages
RUN pip3 install --no-cache-dir numpy pandas matplotlib seaborn scikit-learn \
    jupyter notebook jupyterlab ipywidgets \
    statsmodels scipy xgboost lightgbm catboost

# Install deep learning frameworks with CPU support
RUN pip3 install --no-cache-dir tensorflow tensorflow-hub keras \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Install NLP libraries
RUN pip3 install --no-cache-dir nltk spacy transformers \
    gensim textblob wordcloud && \
    python3 -m spacy download en_core_web_sm && \
    python3 -m nltk.downloader punkt stopwords wordnet

# Install web development and data visualization packages
RUN pip3 install --no-cache-dir flask django fastapi uvicorn \
    dash plotly streamlit gradio \
    bokeh holoviews hvplot altair

# Install database and utility libraries
RUN pip3 install --no-cache-dir sqlalchemy pymysql psycopg2-binary \
    requests beautifulsoup4 scrapy selenium \
    pytest black isort mypy pylint

# Set up ngrok
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -q -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip && \
    chmod +x ngrok

# Configure SSH
RUN mkdir -p /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo root:choco | chpasswd

# Create a start script as a separate file
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose required ports
EXPOSE 8080 22 8888

# Run the start script
CMD ["/bin/bash", "/start.sh"]
