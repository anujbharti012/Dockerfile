FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Essential system packages only (as per your requirement)
RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get install -y sudo curl ffmpeg git locales nano python3-pip screen ssh unzip wget man-db manpages openssh-client openssh-server

# Locale setup
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# ngrok setup
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && rm ngrok.zip

# SSH server setup
RUN mkdir -p /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo root:choco | chpasswd

# Clone your bot and install requirements
RUN git clone https://github.com/Choco-criminal/gand-phar-repo.git && \
    cd gand-phar-repo/Choco-master && \
    python3 -m pip install --upgrade pip && \
    python3 -m pip install -r requirements.txt || true

# Startup script
RUN echo '#!/bin/bash' > /start && \
    echo 'set -e' >> /start && \
    echo 'echo "[INFO] Starting ngrok..."' >> /start && \
    echo 'if [ -n "$NGROK_TOKEN" ]; then' >> /start && \
    echo '  ./ngrok config add-authtoken ${NGROK_TOKEN}' >> /start && \
    echo '  ./ngrok tcp --region ap 22 > /ngrok.log 2>&1 &' >> /start && \
    echo '  sleep 2 && grep "tcp://" /ngrok.log || echo "Ngrok tunnel not ready"' >> /start && \
    echo 'fi' >> /start && \
    echo '/usr/sbin/sshd -D &> /sshd.log &' >> /start && \
    echo 'cd gand-phar-repo/Choco-master' >> /start && \
    echo 'echo "[INFO] Starting your bot..."' >> /start && \
    echo 'bash start' >> /start && \
    chmod +x /start

# Expose ports
EXPOSE 22 80 443 3306 5130 5131 5132 5133 5134 5135 8080 8888 8000

ENV PORT=8000

CMD ["/start"]
