FROM ubuntu:latest

# ===== SYSTEM OPTIMIZATION =====
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    NGINX_PORT=8080 \
    SSH_PORT=22

# ===== INSTALL ESSENTIALS =====
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    openssh-server \
    wget \
    unzip \
    net-tools \
    iputils-ping \
    nano \
    htop \
    curl \
    tmux \
    nginx \
    python3 \
    python3-pip \
    socat \
    jq \
    fail2ban \
    && rm -rf /var/lib/apt/lists/*

# ===== SYSTEM CONFIGURATION =====
RUN ln -fs /usr/share/zoneinfo/$TZ /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# ===== SECURITY HARDENING =====
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#Port 22/Port $SSH_PORT/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#GatewayPorts no/GatewayPorts yes/' /etc/ssh/sshd_config && \
    echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config && \
    echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config && \
    echo "ClientAliveCountMax 3" >> /etc/ssh/sshd_config

# Set root password (change to your strong password)
RUN echo 'root:YourSuperStrongPassword123!' | chpasswd && \
 # Lock password initially (unlock in start script)

# ===== NGROK SETUP =====
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip -O ngrok.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip && \
    chmod +x ngrok && \
    mv ngrok /usr/local/bin/

# ===== MONITORING TOOLS =====
RUN pip3 install glances && \
    curl -L https://github.com/aristocratos/bashtop/archive/master.zip -o bashtop.zip && \
    unzip bashtop.zip && \
    mv bashtop-master /opt/bashtop && \
    rm bashtop.zip

# ===== FAIL2BAN CONFIG =====
COPY <<EOF /etc/fail2ban/jail.d/sshd.conf
[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 1h
EOF

# ===== STARTUP SCRIPT =====
COPY <<EOF /start.sh
#!/bin/bash

# Unlock root account

# Start services
service fail2ban start
service ssh start

# Start monitoring in tmux
tmux new-session -d -s monitoring 'glances'
tmux new-window -t monitoring -n bashtop 'cd /opt/bashtop && ./bashtop'

# Start Ngrok with auto-restart
while true; do
  echo -e "\n\033[1;36mStarting Ngrok tunnel...\033[0m"
  ngrok config add-authtoken $NGROK_TOKEN
  ngrok tcp $SSH_PORT --log=stdout &
  
  # Wait for tunnel and show URL
  sleep 5
  TUNNEL_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')
  echo -e "\n\033[1;32mSSH Tunnel Ready!\033[0m"
  echo -e "Connect using: \033[1;33mssh -p $(echo $TUNNEL_URL | cut -d: -f3) root@$(echo $TUNNEL_URL | cut -d: -f2 | sed 's#//##')\033[0m"
  
  # Start web dashboard
  echo "<h1>SSH Tunnel Active</h1><p>$TUNNEL_URL</p>" > /var/www/html/index.html
  nginx -g 'daemon off;' &
  
  # Keep container running
  wait
  echo -e "\033[1;31mNgrok tunnel closed. Restarting...\033[0m"
  sleep 2
done
EOF

RUN chmod +x /start.sh

# ===== PORTS =====
EXPOSE $SSH_PORT $NGINX_PORT

# ===== HEALTH CHECK =====
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD netstat -tuln | grep -q ":$SSH_PORT.*LISTEN" || exit 1

# ===== CLEANUP =====
RUN apt-get clean && \
    rm -rf /tmp/* /var/tmp/*

# ===== START =====
CMD ["/start.sh"]
