FROM ubuntu:22.04

# Base system and dependencies
RUN apt-get -y update && apt-get -y upgrade && apt-get install -y sudo
RUN apt-get install -y curl ffmpeg git locales nano python3-pip screen ssh unzip wget
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# Install Node.js (optional but included)
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash -
RUN apt-get install -y nodejs
ENV LANG en_US.utf8

# Ngrok token setup
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}

# Install ngrok
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
RUN unzip ngrok.zip

# SSH setup
RUN mkdir -p /run/sshd
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config 
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
RUN echo root:choco | chpasswd

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

# Expose ports (22 for SSH, 8000 for HTTP health check, others if needed)
EXPOSE 22 80 443 3306 5130 5131 5132 5133 5134 5135 8080 8888 8000

# Set default port (used in Render health check or default HTTP server)
ENV PORT=8000

# Run startup script
CMD ["/start"]
