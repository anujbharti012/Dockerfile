FROM ubuntu:latest

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Configure locale and timezone
RUN apt-get update -y && \
    apt-get install -y locales tzdata && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
    ln -fs /usr/share/zoneinfo/UTC /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata

ENV LANG en_US.utf8
ENV TZ UTC

# Install necessary packages
RUN apt-get install -y --no-install-recommends \
    openssh-server \
    wget \
    unzip \
    net-tools \
    iputils-ping \
    nano \
    htop \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH
RUN mkdir /var/run/sshd && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "GatewayPorts yes" >> /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Set root password (change 'daxx' to your preferred password)
RUN echo 'root:choco' | chpasswd

# Install Ngrok
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip -O ngrok.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip && \
    chmod +x ngrok

# Create startup script
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'service ssh start' >> /start.sh && \
    echo './ngrok config add-authtoken $NGROK_TOKEN' >> /start.sh && \
    echo './ngrok tcp 22 --log=stdout &' >> /start.sh && \
    echo 'echo "Waiting for Ngrok to initialize..."' >> /start.sh && \
    echo 'sleep 5' >> /start.sh && \
    echo 'curl -s http://localhost:4040/api/tunnels | grep -o "tcp://[0-9a-z.-]*:[0-9]*"' >> /start.sh && \
    echo 'echo "SSH is ready for connection!"' >> /start.sh && \
    echo '/usr/sbin/sshd -D' >> /start.sh && \
    chmod +x /start.sh

# Health check (optional)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD netstat -an | grep 22 | grep LISTEN || exit 1

# Expose SSH port
EXPOSE 22

# Clean up
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

CMD ["/start.sh"]
