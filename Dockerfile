FROM ubuntu:22.04

# Install base dependencies
RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get install -y sudo curl ffmpeg git locales nano python3-pip screen ssh unzip wget openssh-server

# Set up locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install Node.js
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs

# Configure SSH for stability
RUN mkdir -p /run/sshd && \
    mkdir -p /root/.ssh && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'ClientAliveInterval 60' >> /etc/ssh/sshd_config && \
    echo 'ClientAliveCountMax 3' >> /etc/ssh/sshd_config && \
    echo 'TCPKeepAlive yes' >> /etc/ssh/sshd_config && \
    echo root:choco | chpasswd

# Install and configure Ngrok
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip && \
    chmod +x ngrok

# Create enhanced start script with connection stability
RUN echo "#!/bin/bash" > /start && \
    echo "set -e" >> /start && \
    echo "" >> /start && \
    echo "# Configure ngrok" >> /start && \
    echo "./ngrok config add-authtoken \${NGROK_TOKEN}" >> /start && \
    echo "" >> /start && \
    echo "# Start ngrok with better stability" >> /start && \
    echo "./ngrok tcp --region ap 22 --log stdout &" >> /start && \
    echo "NGROK_PID=\$!" >> /start && \
    echo "" >> /start && \
    echo "# Wait for ngrok to establish tunnel" >> /start && \
    echo "sleep 10" >> /start && \
    echo "" >> /start && \
    echo "# Start SSH daemon" >> /start && \
    echo "/usr/sbin/sshd -D &" >> /start && \
    echo "SSH_PID=\$!" >> /start && \
    echo "" >> /start && \
    echo "# Start HTTP server for Render" >> /start && \
    echo "python3 -m http.server 8080 --bind 0.0.0.0 &" >> /start && \
    echo "HTTP_PID=\$!" >> /start && \
    echo "" >> /start && \
    echo "# Monitor and restart services if they fail" >> /start && \
    echo "while true; do" >> /start && \
    echo "    # Check if ngrok is running" >> /start && \
    echo "    if ! kill -0 \$NGROK_PID 2>/dev/null; then" >> /start && \
    echo "        echo 'Restarting ngrok...'" >> /start && \
    echo "        ./ngrok tcp --region ap 22 --log stdout &" >> /start && \
    echo "        NGROK_PID=\$!" >> /start && \
    echo "    fi" >> /start && \
    echo "" >> /start && \
    echo "    # Check if SSH is running" >> /start && \
    echo "    if ! kill -0 \$SSH_PID 2>/dev/null; then" >> /start && \
    echo "        echo 'Restarting SSH...'" >> /start && \
    echo "        /usr/sbin/sshd -D &" >> /start && \
    echo "        SSH_PID=\$!" >> /start && \
    echo "    fi" >> /start && \
    echo "" >> /start && \
    echo "    # Check if HTTP server is running" >> /start && \
    echo "    if ! kill -0 \$HTTP_PID 2>/dev/null; then" >> /start && \
    echo "        echo 'Restarting HTTP server...'" >> /start && \
    echo "        python3 -m http.server 8080 --bind 0.0.0.0 &" >> /start && \
    echo "        HTTP_PID=\$!" >> /start && \
    echo "    fi" >> /start && \
    echo "" >> /start && \
    echo "    sleep 30" >> /start && \
    echo "done" >> /start && \
    chmod 755 /start

# Create ngrok status check script
RUN echo "#!/bin/bash" > /check_ngrok && \
    echo "curl -s http://localhost:4040/api/tunnels | python3 -c \"import sys,json; data=json.load(sys.stdin); print('SSH Tunnel:', data['tunnels'][0]['public_url'] if data['tunnels'] else 'Not available')\"" >> /check_ngrok && \
    chmod 755 /check_ngrok

# Expose ports
EXPOSE 22 80 443 8080 4040 5130 5131 5132 5133 5134 5135 3306

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

CMD ["/start"]
