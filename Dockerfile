FROM ubuntu:latest

# Install dependencies
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    locales \
    ssh \
    wget \
    unzip \
    curl \
    python3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install ngrok
RUN wget -q -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip && \
    chmod +x ngrok

# Configure SSH with root access
RUN mkdir -p /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'root:choco' | chpasswd

# Create web directory for health checks
RUN mkdir -p /var/www && \
    echo "SSH Tunnel Active" > /var/www/index.html

# Startup script
RUN echo "#!/bin/bash" > /start.sh && \
    echo "set -e" >> /start.sh && \
    echo "./ngrok config add-authtoken \${NGROK_TOKEN} || { echo 'Ngrok failed'; exit 1; }" >> /start.sh && \
    echo "./ngrok tcp 22 &" >> /start.sh && \
    echo "python3 -m http.server 80 --directory /var/www &" >> /start.sh && \
    echo "/usr/sbin/sshd -D" >> /start.sh && \
    chmod +x /start.sh

EXPOSE 80 22
HEALTHCHECK --interval=30s --timeout=10s CMD curl -f http://localhost/ || exit 1
CMD ["/start.sh"]
