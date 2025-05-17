FROM ubuntu:latest

# ===== SYSTEM OPTIMIZATION =====
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
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
    screen \
    nginx \
    python3 \
    python3-pip \
    socat \
    jq \
    fail2ban \
    tzdata \
    locales && \
    rm -rf /var/lib/apt/lists/*

# ===== SYSTEM CONFIGURATION =====
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8

# ===== SECURITY HARDENING =====
RUN mkdir -p /var/run/sshd && \
    sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#GatewayPorts no/GatewayPorts yes/' /etc/ssh/sshd_config && \
    echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config && \
    echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config && \
    echo "ClientAliveCountMax 3" >> /etc/ssh/sshd_config

# Set root password (change to your strong password)
RUN echo 'root:YourSuperStrongPassword123!' | chpasswd

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
RUN mkdir -p /etc/fail2ban/jail.d/ && \
    echo -e "[sshd]\nenabled = true\nport = $SSH_PORT\nfilter = sshd\nlogpath = /var/log/auth.log\nmaxretry = 3\nbantime = 1h" > /etc/fail2ban/jail.d/sshd.conf

# ===== STARTUP SCRIPT =====
RUN echo -e '#!/bin/bash\n\n# Start services\nservice fail2ban start\nservice ssh start\n\n# Start monitoring in tmux\ntmux new-session -d -s monitoring "glances"\ntmux new-window -t monitoring -n bashtop "cd /opt/bashtop && ./bashtop"\n\n# Start Ngrok with auto-restart\nwhile true; do\n  echo -e "\\n\\033[1;36mStarting Ngrok tunnel...\\033[0m"\n  ngrok config add-authtoken $NGROK_TOKEN\n  ngrok tcp $SSH_PORT --log=stdout &\n  \n  # Wait for tunnel and show URL\n  sleep 5\n  TUNNEL_URL=$(curl -s http://localhost:4040/api/tunnels | jq
