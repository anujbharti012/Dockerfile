FROM ubuntu:22.04

# Install all required packages
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y sudo curl ffmpeg git locales nano python3-pip screen ssh unzip wget

# Configure locale and install Node.js
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs
ENV LANG en_US.utf8

# Ngrok setup with URL display
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    chmod +x ngrok

# SSH setup
RUN mkdir /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo root:choco | chpasswd

# Create start script with Ngrok URL display
RUN echo '#!/bin/bash' > /start.sh && \
    echo './ngrok config add-authtoken ${NGROK_TOKEN} &&' >> /start.sh && \
    echo './ngrok tcp 22 --log=stdout > ngrok.log &' >> /start.sh && \
    echo 'sleep 5' >> /start.sh && \
    echo 'echo "=== Ngrok SSH Tunnel ==="' >> /start.sh && \
    echo 'curl -s http://localhost:4040/api/tunnels | grep -o "tcp://[^\"]*"' >> /start.sh && \
    echo 'echo "=== SSH Credentials ==="' >> /start.sh && \
    echo 'echo "Username: root"' >> /start.sh && \
    echo 'echo "Password: choco"' >> /start.sh && \
    echo '/usr/sbin/sshd -D' >> /start.sh && \
    chmod +x /start.sh

# Python web server for Render
RUN echo 'from http.server import BaseHTTPRequestHandler, HTTPServer' > /server.py && \
    echo 'import os, subprocess' >> /server.py && \
    echo 'class Handler(BaseHTTPRequestHandler):' >> /server.py && \
    echo '    def do_HEAD(self):' >> /server.py && \
    echo '        self.send_response(200)' >> /server.py && \
    echo '        self.end_headers()' >> /server.py && \
    echo '    def do_GET(self):' >> /server.py && \
    echo '        self.send_response(200)' >> /server.py && \
    echo '        self.end_headers()' >> /server.py && \
    echo '        ssh_info = subprocess.getoutput("curl -s http://localhost:4040/api/tunnels | grep -o \\"tcp://[^\\\"]*\\"")' >> /server.py && \
    echo '        response = f"SSH Access:<br>{ssh_info}<br>User: root<br>Pass: choco"' >> /server.py && \
    echo '        self.wfile.write(response.encode())' >> /server.py

EXPOSE ${PORT:-10000}

CMD /start.sh & python3 /server.py --port ${PORT:-10000} --bind 0.0.0.0
