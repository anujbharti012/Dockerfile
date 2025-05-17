FROM ubuntu:latest

# Set up environment
RUN apt-get update -y && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends \
    locales \
    ssh \
    wget \
    unzip \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install Python packages using ensurepip
RUN python3 -m ensurepip --upgrade && \
    python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel && \
    python3 -m pip install --no-cache-dir flask gunicorn

# Install ngrok
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -q -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip && \
    chmod +x ngrok

# Configure SSH securely
RUN mkdir -p /run/sshd && \
    useradd -m -s /bin/bash tunneluser && \
    mkdir -p /home/tunneluser/.ssh && \
    chmod 700 /home/tunneluser/.ssh

# Minimal SSH config (key-based auth only)
RUN echo 'PermitRootLogin no' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config && \
    echo 'AllowUsers tunneluser' >> /etc/ssh/sshd_config

# Create proper Flask application
RUN echo "from flask import Flask" > /app.py && \
    echo "app = Flask(__name__)" >> /app.py && \
    echo "@app.route('/')" >> /app.py && \
    echo "def home():" >> /app.py && \
    echo "    return 'SSH tunnel active. Use ngrok endpoint to connect.', 200" >> /app.py && \
    echo "@app.route('/health')" >> /app.py && \
    echo "def health():" >> /app.py && \
    echo "    return 'OK', 200" >> /app.py

ENV FLASK_APP=app.py
ENV FLASK_ENV=production

# Startup script
RUN echo "#!/bin/bash" > /start.sh && \
    echo "./ngrok config add-authtoken \${NGROK_TOKEN} &&" >> /start.sh && \
    echo "./ngrok tcp 22 &" >> /start.sh && \
    echo "gunicorn --bind 0.0.0.0:80 app:app &" >> /start.sh && \
    echo "/usr/sbin/sshd -D" >> /start.sh && \
    chmod +x /start.sh

# Required ports (80 for web, 22 for SSH)
EXPOSE 80 22

HEALTHCHECK --interval=30s --timeout=10s \
    CMD curl -f http://localhost/health || exit 1

CMD ["/start.sh"]
