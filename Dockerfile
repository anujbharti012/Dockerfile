FROM ubuntu:22.04

# Update system and install dependencies
RUN apt-get -y update && apt-get -y upgrade && apt-get install -y sudo
RUN sudo apt-get install -y curl ffmpeg git locales nano python3-pip screen ssh unzip wget

# Set up locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install Node.js (v21)
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash -
RUN sudo apt-get install -y nodejs

# Install ngrok
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
RUN unzip ngrok.zip
RUN ./ngrok config add-authtoken 2bmDkAveY0grVVDlgwVXiOP5ia2_3vyBFrEpUdZou7veySL6p

# Setup SSH
RUN mkdir -p /run/sshd
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config 
RUN echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
RUN echo root:choco | chpasswd

# Create a startup script
RUN echo '#!/bin/bash' > /start && \
    echo './ngrok tcp --region ap 22 &>/dev/null &' >> /start && \
    echo '/usr/sbin/sshd' >> /start && \
    echo 'python3 -m http.server ${PORT:-8080} --bind 0.0.0.0' >> /start && \
    chmod 755 /start

# Expose useful ports
EXPOSE 22 80 443 3306 5130 5131 5132 5133 5134 5135 8080 8888

# Set the default port for HTTP server
ENV PORT=8080

# Start script
CMD ["/start"]
