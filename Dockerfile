FROM ubuntu:22.04

# Install core packages
RUN apt-get update -y && apt-get upgrade -y && apt-get install -y \
    sudo curl ffmpeg git locales nano python3-pip screen ssh unzip wget

# Set up locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install Node.js
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash - \
    && apt-get install -y nodejs

# Install ngrok
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip \
    && unzip ngrok.zip

# Setup SSH
RUN mkdir /run/sshd \
    && echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config \
    && echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config \
    && echo root:choco | chpasswd

# Expose relevant ports
EXPOSE 22 80 443 8080 5130 5131 5132 5133 5134 5135 3306

# Start script
RUN echo '#!/bin/bash' > /start \
    && echo "./ngrok config add-authtoken \$NGROK_TOKEN" >> /start \
    && echo "./ngrok tcp --region ap 22 &>/dev/null &" >> /start \
    && echo "/usr/sbin/sshd &" >> /start \
    && echo "python3 -m http.server 8080 --bind 0.0.0.0 &" >> /start \
    && echo "tail -f /dev/null" >> /start \
    && chmod +x /start

CMD ["/start"]

