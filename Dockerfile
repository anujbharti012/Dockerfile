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
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo 'ClientAliveInterval 60' >> /etc/ssh/sshd_config && \
    echo 'ClientAliveCountMax 3' >> /etc/ssh/sshd_config && \
    echo 'TCPKeepAlive yes' >> /etc/ssh/sshd_config && \
    echo 'UsePAM no' >> /etc/ssh/sshd_config && \
    echo 'PrintMotd no' >> /etc/ssh/sshd_config && \
    echo 'AcceptEnv LANG LC_*' >> /etc/ssh/sshd_config && \
    echo root:choco | chpasswd

# Install and configure Ngrok
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip && \
    chmod +x ngrok

# Create enhanced start script with Render compatibility
RUN echo "#!/bin/bash" > /start && \
    echo "set -e" >> /start && \
    echo "" >> /start && \
    echo "# Set default port for Render" >> /start && \
    echo "export PORT=\${PORT:-10000}" >> /start && \
    echo "" >> /start && \
    echo "# Configure ngrok" >> /start && \
    echo "./ngrok config add-authtoken \${NGROK_TOKEN}" >> /start && \
    echo "" >> /start && \
    echo "# Generate SSH host keys" >> /start && \
    echo "ssh-keygen -A 2>/dev/null || echo 'SSH keys already exist'" >> /start && \
    echo "" >> /start && \
    echo "# Start SSH daemon with Render-friendly settings" >> /start && \
    echo "/usr/sbin/sshd -D -e -f /etc/ssh/sshd_config &" >> /start && \
    echo "SSH_PID=\$!" >> /start && \
    echo "sleep 2" >> /start && \
    echo "" >> /start && \
    echo "# Start ngrok for SSH tunnel" >> /start && \
    echo "./ngrok tcp 22 --log stdout &" >> /start && \
    echo "NGROK_PID=\$!" >> /start && \
    echo "sleep 5" >> /start && \
    echo "" >> /start && \
    echo "# Start HTTP server on Render's required port" >> /start && \
    echo "python3 -c \"" >> /start && \
    echo "import http.server" >> /start && \
    echo "import socketserver" >> /start && \
    echo "import os" >> /start && \
    echo "import subprocess" >> /start && \
    echo "import json" >> /start && \
    echo "import threading" >> /start && \
    echo "import time" >> /start && \
    echo "" >> /start && \
    echo "PORT = int(os.environ.get('PORT', 10000))" >> /start && \
    echo "" >> /start && \
    echo "class CustomHandler(http.server.SimpleHTTPRequestHandler):" >> /start && \
    echo "    def do_GET(self):" >> /start && \
    echo "        if self.path == '/':" >> /start && \
    echo "            self.send_response(200)" >> /start && \
    echo "            self.send_header('Content-type', 'text/html')" >> /start && \
    echo "            self.end_headers()" >> /start && \
    echo "            # Get ngrok tunnel info" >> /start && \
    echo "            try:" >> /start && \
    echo "                import urllib.request" >> /start && \
    echo "                with urllib.request.urlopen('http://localhost:4040/api/tunnels') as response:" >> /start && \
    echo "                    data = json.loads(response.read().decode())" >> /start && \
    echo "                    if data['tunnels']:" >> /start && \
    echo "                        tunnel_url = data['tunnels'][0]['public_url']" >> /start && \
    echo "                        host = tunnel_url.split('://')[1].split(':')[0]" >> /start && \
    echo "                        port = tunnel_url.split(':')[-1]" >> /start && \
    echo "                        ssh_cmd = f'ssh -p {port} root@{host}'" >> /start && \
    echo "                    else:" >> /start && \
    echo "                        ssh_cmd = 'Ngrok tunnel not ready yet'" >> /start && \
    echo "            except:" >> /start && \
    echo "                ssh_cmd = 'Ngrok API not available'" >> /start && \
    echo "            " >> /start && \
    echo "            html = f'''<!DOCTYPE html>" >> /start && \
    echo "<html><head><title>VPS Terminal Access</title></head>" >> /start && \
    echo "<body style=\"font-family: Arial, sans-serif; margin: 40px;\">" >> /start && \
    echo "<h1>🖥️ VPS Terminal Ready</h1>" >> /start && \
    echo "<div style=\"background: #f0f0f0; padding: 20px; border-radius: 5px; margin: 20px 0;\">" >> /start && \
    echo "<h3>SSH Connection Command:</h3>" >> /start && \
    echo "<code style=\"background: #333; color: #0f0; padding: 10px; display: block; border-radius: 3px;\">{ssh_cmd}</code>" >> /start && \
    echo "</div>" >> /start && \
    echo "<p><strong>Username:</strong> root</p>" >> /start && \
    echo "<p><strong>Password:</strong> choco</p>" >> /start && \
    echo "<p><strong>Status:</strong> Services running ✅</p>" >> /start && \
    echo "</body></html>'''" >> /start && \
    echo "            self.wfile.write(html.encode())" >> /start && \
    echo "        else:" >> /start && \
    echo "            super().do_GET()" >> /start && \
    echo "" >> /start && \
    echo "with socketserver.TCPServer(('0.0.0.0', PORT), CustomHandler) as httpd:" >> /start && \
    echo "    print(f'HTTP server running on port {PORT}')" >> /start && \
    echo "    httpd.serve_forever()" >> /start && \
    echo "\" &" >> /start && \
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
    echo "        ssh-keygen -A" >> /start && \
    echo "        /usr/sbin/sshd -D -e &" >> /start && \
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

# Expose ports (Render will use PORT env var)
EXPOSE 22 80 443 4040 5130 5131 5132 5133 5134 5135 3306

# Health check for Render
HEALTHCHECK --interval=30s --timeout=30s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:${PORT:-10000}/ || exit 1

CMD ["/start"]
