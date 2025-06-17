FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Base setup
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    sudo curl ffmpeg git locales nano python2 python2-dev python-is-python2 \
    python3-pip screen ssh unzip wget man-db manpages manpages-dev \
    openssh-client openssh-server openssh-sftp-server openssh-known-hosts

# Set locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install pip2 safely (Ubuntu 22.04 doesn't come with it)
RUN curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py && \
    python2 get-pip.py && rm get-pip.py

# Optional Node.js
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs

# Add ngrok auth token if given
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}

# Install ngrok
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && rm ngrok.zip

# Setup SSH
RUN mkdir -p /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo root:choco | chpasswd

# Clone your bot repo and install Python 2 dependencies
RUN git clone https://github.com/Choco-criminal/gand-phar-repo.git && \
    cd gand-phar-repo/Choco-master && \
    pip2 install -r requirements.txt

# Create startup script
RUN echo '#!/bin/bash' > /start && \
    echo 'set -e' >> /start && \
    echo '' >> /start && \
    echo 'if [ -n "$NGROK_TOKEN" ]; then' >> /start && \
    echo '  ./ngrok config add-authtoken ${NGROK_TOKEN}' >> /start && \
    echo '  ./ngrok tcp --region ap 22 > /ngrok.log 2>&1 &' >> /start && \
    echo '  sleep 2 && grep "tcp://" /ngrok.log || echo "ngrok tunnel not ready"' >> /start && \
    echo 'fi' >> /start && \
    echo '' >> /start && \
    echo '/usr/sbin/sshd -D &> /sshd.log &' >> /start && \
    echo 'cd gand-phar-repo/Choco-master' >> /start && \
    echo 'echo "[INFO] Starting your bot..."' >> /start && \
    echo 'bash start' >> /start && \
    chmod +x /start

# Expose all required ports
EXPOSE 22 80 443 3306 5130 5131 5132 5133 5134 5135 8080 8888 8000

# Health check port fallback
ENV PORT=8000

CMD ["/start"]
