FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y sudo curl ffmpeg git locales nano python3-pip screen ssh unzip wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs

# Create directory for SSH service
RUN mkdir -p /run/sshd

# Configure SSH
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo root:choco | chpasswd

# Download and setup ngrok
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip && \
    chmod +x ngrok

# Create startup script
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'if [ -z "$NGROK_TOKEN" ]; then' >> /start.sh && \
    echo '  echo "Error: NGROK_TOKEN is not set. Please set it in your Render environment variables."' >> /start.sh && \
    echo '  exit 1' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo './ngrok config add-authtoken ${NGROK_TOKEN}' >> /start.sh && \
    echo './ngrok tcp --region ap 22 --log=stdout > /var/log/ngrok.log 2>&1 &' >> /start.sh && \
    echo 'echo "ngrok started, waiting for tunnel URL..."' >> /start.sh && \
    echo 'sleep 5' >> /start.sh && \
    echo 'curl -s http://localhost:4040/api/tunnels | grep -o "tcp://.*"' >> /start.sh && \
    echo '/usr/sbin/sshd -D' >> /start.sh && \
    chmod +x /start.sh

# Expose necessary ports
EXPOSE 22 80 443 3306 4040 8080 8888 5130 5131 5132 5133 5134 5135

# Define healthcheck to ensure container is running properly
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD pgrep sshd || exit 1

CMD ["/start.sh"]
