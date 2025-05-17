FROM ubuntu:latest

# Set up environment
RUN apt update -y && \
    apt upgrade -y && \
    apt install -y locales ssh wget unzip python3-flask && \
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

# Configure SSH securely
RUN mkdir -p /run/sshd && \
    useradd -m -s /bin/bash tunneluser && \
    mkdir -p /home/tunneluser/.ssh && \
    chmod 700 /home/tunneluser/.ssh

# Minimal SSH config (key-based auth only)
RUN echo 'PermitRootLogin no' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config && \
    echo 'AllowUsers tunneluser' >> /etc/ssh/sshd_config

# Create web server for Render.com (required)
RUN echo "from flask import Flask; app = Flask(__name__)" > /webapp.py && \
    echo "@app.route('/')" >> /webapp.py && \
    echo "def home(): return 'SSH tunnel active. Use ngrok endpoint to connect.', 200" >> /webapp.py

# Startup script
RUN echo "#!/bin/bash" > /start.sh && \
    echo "./ngrok config add-authtoken \${NGROK_TOKEN} &&" >> /start.sh && \
    echo "./ngrok tcp 22 &" >> /start.sh && \
    echo "flask run --host=0.0.0.0 --port=80 &" >> /start.sh && \
    echo "/usr/sbin/sshd -D" >> /start.sh && \
    chmod +x /start.sh

# Required ports (22 for SSH, 80 for web)
EXPOSE 80 22

HEALTHCHECK --interval=30s --timeout=10s \
    CMD curl -f http://localhost/ || exit 1

CMD ["/start.sh"]
