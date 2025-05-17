FROM ubuntu:latest

# 1. Base system setup with retry logic for apt
RUN apt-get update -y --fix-missing && \
    apt-get install -y --no-install-recommends \
    locales \
    ssh \
    wget \
    unzip \
    ca-certificates \
    curl \
    python3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. Set locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# 3. Robust ngrok installation with multiple fallbacks
RUN mkdir -p /tmp/ngrok && cd /tmp/ngrok && \
    (wget -q --show-progress -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip || \
     wget -q --show-progress -O ngrok.zip https://bin.equinox.io/a/nmkK3DkqZEB/ngrok-v3-stable-linux-amd64.zip || \
     wget -q --show-progress -O ngrok.zip https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip) && \
    unzip -o ngrok.zip && \
    mv ngrok /usr/local/bin/ && \
    chmod +x /usr/local/bin/ngrok && \
    cd / && rm -rf /tmp/ngrok

# 4. SSH Configuration with Root Access
RUN mkdir -p /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'root:choco' | chpasswd && \
    mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh

# 5. Health check endpoint
RUN mkdir -p /var/www && \
    echo "SSH Tunnel Active" > /var/www/index.html

# 6. Startup script with error handling
RUN echo "#!/bin/bash" > /start.sh && \
    echo "set -e" >> /start.sh && \
    echo "if [ -z \"\${NGROK_TOKEN}\" ]; then" >> /start.sh && \
    echo "  echo \"ERROR: NGROK_TOKEN environment variable required\"" >> /start.sh && \
    echo "  exit 1" >> /start.sh && \
    echo "fi" >> /start.sh && \
    echo "ngrok config add-authtoken \"\${NGROK_TOKEN}\" || { echo \"Ngrok auth failed\"; exit 1; }" >> /start.sh && \
    echo "ngrok tcp 22 &" >> /start.sh && \
    echo "python3 -m http.server 80 --directory /var/www &" >> /start.sh && \
    echo "/usr/sbin/sshd -D" >> /start.sh && \
    chmod +x /start.sh

EXPOSE 80 22
HEALTHCHECK --interval=30s --timeout=10s CMD curl -f http://localhost/ || exit 1
CMD ["/start.sh"]
