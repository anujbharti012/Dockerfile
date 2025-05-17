FROM ubuntu:latest

# 1. Install system dependencies
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    locales \
    ssh \
    wget \
    unzip \
    python3 \
    # Use Python's built-in HTTP server instead of Flask
    # Install curl for health checks
    curl \
    && rm -rf /var/lib/apt/lists/*

# 2. Set locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# 3. Install ngrok (no Python dependencies)
RUN wget -q -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip && \
    chmod +x ngrok

# 4. Configure SSH securely
RUN mkdir -p /run/sshd && \
    useradd -m -s /bin/bash tunneluser && \
    mkdir -p /home/tunneluser/.ssh && \
    chmod 700 /home/tunneluser/.ssh

# 5. SSH configuration (key-based auth only)
RUN echo 'PermitRootLogin no' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config && \
    echo 'AllowUsers tunneluser' >> /etc/ssh/sshd_config

# 6. Create a simple health check endpoint using Python's built-in HTTP server
RUN echo "Healthy" > /health.txt

# 7. Startup script
RUN echo "#!/bin/bash" > /start.sh && \
    echo "./ngrok config add-authtoken \${NGROK_TOKEN} &&" >> /start.sh && \
    echo "./ngrok tcp 22 &" >> /start.sh && \
    # Using Python's built-in HTTP server on port 80
    echo "python3 -m http.server 80 &" >> /start.sh && \
    echo "/usr/sbin/sshd -D" >> /start.sh && \
    chmod +x /start.sh

# 8. Required ports (80 for web, 22 for SSH)
EXPOSE 80 22

# 9. Health check using the simple HTTP server
HEALTHCHECK --interval=30s --timeout=10s \
    CMD curl -f http://localhost/health.txt || exit 1

CMD ["/start.sh"]
