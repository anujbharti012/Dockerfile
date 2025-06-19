

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install core packages
RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get install -y sudo curl ffmpeg git locales nano python3-pip screen ssh unzip wget man-db manpages openssh-client openssh-server

# Set up locale
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# Install Node.js (for PyTgCalls)
RUN curl -fsSL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs

# Install ngrok
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && rm ngrok.zip

# Setup SSH for root access
RUN mkdir -p /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo root:choco | chpasswd

# Clone your bot repository
RUN git clone https://github.com/Choco-criminal/gand-phar-repo.git

# Install Python dependencies
RUN cd gand-phar-repo/Choco-master && \
    python3 -m pip install --upgrade pip && \
    python3 -m pip install -r requirements.txt || true

# Create startup script
RUN echo '#!/bin/bash' > /start && \
    echo 'set -e' >> /start && \
    echo 'echo "[INFO] Starting SSH..."' >> /start && \
    echo '/usr/sbin/sshd -D > /sshd.log 2>&1 &' >> /start && \
    echo '' >> /start && \
    echo 'if [ -n "$NGROK_TOKEN" ]; then' >> /start && \
    echo '  echo "[INFO] Starting ngrok for SSH..."' >> /start && \
    echo '  ./ngrok config add-authtoken ${NGROK_TOKEN}' >> /start && \
    echo '  ./ngrok tcp --region ap 22 > /ngrok.log 2>&1 &' >> /start && \
    echo '  sleep 3 && grep "tcp://" /ngrok.log || echo "Ngrok tunnel not ready."' >> /start && \
    echo 'fi' >> /start && \
    echo '' >> /start && \
    echo 'echo "[INFO] Starting HTTP server for Render health check..."' >> /start && \
    echo 'python3 -m http.server ${PORT:-8000} --bind 0.0.0.0 > /dev/null 2>&1 &' >> /start && \
    echo '' >> /start && \
    echo 'echo "[INFO] Starting your bot now..."' >> /start && \
    echo 'cd gand-phar-repo/Choco-master' >> /start && \
    echo 'bash start' >> /start && \
    chmod +x /start

# Expose ports
EXPOSE 22 8000

# Set default port for Render
ENV PORT=8000

# Start the bot and services
CMD ["/start"]


FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install core packages
RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get install -y sudo curl ffmpeg git locales nano python3-pip screen ssh unzip wget man-db manpages openssh-client openssh-server

# Set up locale
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# Install Node.js (for PyTgCalls)
RUN curl -fsSL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs

# Install ngrok
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && rm ngrok.zip

# Setup SSH for root access
RUN mkdir -p /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo root:choco | chpasswd

# Clone your bot repository
RUN git clone https://github.com/Choco-criminal/gand-phar-repo.git

# Install Python dependencies
RUN cd gand-phar-repo/Choco-master && \
    python3 -m pip install --upgrade pip && \
    python3 -m pip install -r requirements.txt || true

# Create startup script
RUN echo '#!/bin/bash' > /start && \
    echo 'set -e' >> /start && \
    echo 'echo "[INFO] Starting SSH..."' >> /start && \
    echo '/usr/sbin/sshd -D > /sshd.log 2>&1 &' >> /start && \
    echo '' >> /start && \
    echo 'if [ -n "$NGROK_TOKEN" ]; then' >> /start && \
    echo '  echo "[INFO] Starting ngrok for SSH..."' >> /start && \
    echo '  ./ngrok config add-authtoken ${NGROK_TOKEN}' >> /start && \
    echo '  ./ngrok tcp --region ap 22 > /ngrok.log 2>&1 &' >> /start && \
    echo '  sleep 3 && grep "tcp://" /ngrok.log || echo "Ngrok tunnel not ready."' >> /start && \
    echo 'fi' >> /start && \
    echo '' >> /start && \
    echo 'echo "[INFO] Starting HTTP server for Render health check..."' >> /start && \
    echo 'python3 -m http.server ${PORT:-8000} --bind 0.0.0.0 > /dev/null 2>&1 &' >> /start && \
    echo '' >> /start && \
    echo 'echo "[INFO] Starting your bot now..."' >> /start && \
    echo 'cd gand-phar-repo/Choco-master' >> /start && \
    echo 'bash start' >> /start && \
    chmod +x /start

# Expose ports
EXPOSE 22 8000

# Set default port for Render
ENV PORT=8000

# Start the bot and services
CMD ["/start"]


FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install core packages
RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get install -y sudo curl ffmpeg git locales nano python3-pip screen ssh unzip wget man-db manpages openssh-client openssh-server

# Set up locale
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# Install Node.js (for PyTgCalls)
RUN curl -fsSL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs

# Install ngrok
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && rm ngrok.zip

# Setup SSH for root access
RUN mkdir -p /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo root:choco | chpasswd

# Clone your bot repository
RUN git clone https://github.com/Choco-criminal/gand-phar-repo.git

# Install Python dependencies
RUN cd gand-phar-repo/Choco-master && \
    python3 -m pip install --upgrade pip && \
    python3 -m pip install -r requirements.txt || true

# Create startup script
RUN echo '#!/bin/bash' > /start && \
    echo 'set -e' >> /start && \
    echo 'echo "[INFO] Starting SSH..."' >> /start && \
    echo '/usr/sbin/sshd -D > /sshd.log 2>&1 &' >> /start && \
    echo '' >> /start && \
    echo 'if [ -n "$NGROK_TOKEN" ]; then' >> /start && \
    echo '  echo "[INFO] Starting ngrok for SSH..."' >> /start && \
    echo '  ./ngrok config add-authtoken ${NGROK_TOKEN}' >> /start && \
    echo '  ./ngrok tcp --region ap 22 > /ngrok.log 2>&1 &' >> /start && \
    echo '  sleep 3 && grep "tcp://" /ngrok.log || echo "Ngrok tunnel not ready."' >> /start && \
    echo 'fi' >> /start && \
    echo '' >> /start && \
    echo 'echo "[INFO] Starting HTTP server for Render health check..."' >> /start && \
    echo 'python3 -m http.server ${PORT:-8000} --bind 0.0.0.0 > /dev/null 2>&1 &' >> /start && \
    echo '' >> /start && \
    echo 'echo "[INFO] Starting your bot now..."' >> /start && \
    echo 'cd gand-phar-repo/Choco-master' >> /start && \
    echo 'bash start' >> /start && \
    chmod +x /start

# Expose ports
EXPOSE 22 8000

# Set default port for Render
ENV PORT=8000

# Start the bot and services
CMD ["/start"]
