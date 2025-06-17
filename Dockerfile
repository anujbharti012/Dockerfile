FROM ubuntu:22.04

# Install basic packages
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    sudo curl ffmpeg git locales nano python3-pip screen ssh unzip wget \
    openssh-client && rm -rf /var/lib/apt/lists/*

# Set locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install Node.js
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs

# Setup SSH
RUN mkdir -p /run/sshd
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config 
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
RUN echo root:choco|chpasswd

# Create startup script with Serveo
RUN cat > /start << 'EOF'
#!/bin/bash

# Start SSH daemon
/usr/sbin/sshd

# Start Serveo tunnel (no token needed)
echo "Starting Serveo tunnel..."
ssh -o StrictHostKeyChecking=no -R 80:localhost:22 serveo.net &

# Alternative: Random subdomain
# ssh -o StrictHostKeyChecking=no -R 0:localhost:22 serveo.net &

# Keep container running
echo "Starting HTTP server on port ${PORT:-8000}..."
python3 -m http.server ${PORT:-8000} --bind 0.0.0.0
EOF

RUN chmod 755 /start

# Expose ports
EXPOSE 22 80 443 8000

ENV PORT=8000

CMD ["/start"]
