FROM ubuntu:latest

# 1. Install system dependencies with clean package management
RUN apt-get update -y && \
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
     wget -q --show-progress -O ngrok.zip https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip) && \
    unzip ngrok.zip && \
    mv ngrok /usr/local/bin/ && \
    chmod +x /usr/local/bin/ngrok && \
    cd / && rm -rf /tmp/ngrok

# 4. Configure SSH securely with proper directory structure
RUN mkdir -p /run/sshd && \
    useradd -m -s /bin/bash tunneluser && \
    mkdir -p /home/tunneluser/.ssh && \
    chmod 700 /home/tunneluser/.ssh

# 5. SSH configuration (key-based auth only)
RUN echo 'PermitRootLogin no' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config && \
    echo 'AllowUsers tunneluser' >> /etc/ssh/sshd_config

# 6. Create web directory and health check endpoint
RUN mkdir -p /var/www && \
    echo "SSH Tunnel Active" > /var/www/index.html

# 7. Robust startup script with error handling
RUN echo "#!/bin/bash" > /start.sh && \
    echo "set -e" >> /start.sh && \
    echo "mkdir -p /var/www" >> /start.sh && \
    echo "echo \"SSH Tunnel Active\" > /var/www/index.html" >> /start.sh && \
    echo "if [ -z \"\${NGROK_TOKEN}\" ]; then" >> /start.sh && \
    echo "  echo \"Error: NGROK_TOKEN environment variable required\"" >> /start.sh && \
    echo "  exit 1" >> /start.sh && \
    echo "fi" >> /start.sh && \
    echo "ngrok config add-authtoken \"\${NGROK_TOKEN}\" || { echo \"Failed to configure ngrok\"; exit 1; }" >> /start.sh && \
    echo "ngrok tcp 22 &" >> /start.sh && \
    echo "cd /var/www && python3 -m http.server 80 &" >> /start.sh && \
    echo "/usr/sbin/sshd -D" >> /start.sh && \
    chmod +x /start.sh

# 8. Required ports
EXPOSE 80 22

# 9. Health check
HEALTHCHECK --interval=30s --timeout=10s \
    CMD curl -f http://localhost/ || exit 1

CMD ["/start.sh"]
