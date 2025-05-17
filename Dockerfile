FROM ubuntu:latest

# Set up environment and install dependencies
RUN apt update -y && \
    apt upgrade -y && \
    apt install -y locales ssh wget unzip net-tools && \
    rm -rf /var/lib/apt/lists/*

# Set locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install ngrok
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -q -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip && \
    chmod +x ngrok

# Configure SSH to listen on all interfaces
RUN mkdir -p /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'ListenAddress 0.0.0.0' >> /etc/ssh/sshd_config && \
    echo 'root:choco' | chpasswd

# Create a better startup script with logging
RUN echo "#!/bin/bash" > /daxx.sh && \
    echo "set -x" >> /daxx.sh && \
    echo "./ngrok config add-authtoken ${NGROK_TOKEN} || echo 'Ngrok auth failed'" >> /daxx.sh && \
    echo "./ngrok tcp 22 &" >> /daxx.sh && \
    echo "sleep 5" >> /daxx.sh && \
    echo "netstat -tuln" >> /daxx.sh && \
    echo "/usr/sbin/sshd -D -e" >> /daxx.sh && \
    chmod +x /daxx.sh

EXPOSE 22

# Health check with better debugging
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD netstat -tuln | grep 22 || exit 1

CMD ["/daxx.sh"]
