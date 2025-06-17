FROM ubuntu:22.04

# Prevent prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Base system update and dependencies
RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get install -y sudo curl ffmpeg git locales nano python3-pip screen ssh unzip wget man-db manpages openssh-client openssh-server

# Set locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install Node.js (optional)
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs

# Ngrok auth token setup
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}

# Install ngrok
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip

# SSH setup
RUN mkdir -p /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo root:choco | chpasswd

# Create startup script
RUN echo '#!/bin/bash' > /start && \
    echo 'set -e' >> /start && \
    echo 'if [ -n "$NGROK_TOKEN" ]; then' >> /start && \
    echo '  ./ngrok config add-authtoken ${NGROK_TOKEN}' >> /start && \
    echo '  ./ngrok tcp --region ap 22 &>/dev/null &' >> /start && \
    echo 'fi' >> /start && \
    echo '/usr/sbin/sshd -D &>/dev/null &' >> /start && \
    echo 'python3 -m http.server ${PORT:-8000} --bind 0.0.0.0 &>/dev/null &' >> /start && \
    echo 'tail -f /dev/null' >> /start && \
    chmod +x /start

# Expose ports (22 for SSH, 8000 default for health check)
EXPOSE 22 80 443 3306 5130 5131 5132 5133 5134 5135 8080 8888 8000

# Default port used by health checker or HTTP
ENV PORT=8000

# Start script
CMD ["/start"]
