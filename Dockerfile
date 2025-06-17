FROM ubuntu:22.04

# Install all your existing packages
RUN apt-get -y update && apt-get -y upgrade -y && apt-get install -y sudo
RUN sudo apt-get install -y curl ffmpeg git locales nano python3-pip screen ssh unzip wget  
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash -
RUN sudo apt-get install -y nodejs
ENV LANG en_US.utf8

# SSH and Ngrok setup
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
RUN unzip ngrok.zip
RUN echo "./ngrok config add-authtoken ${NGROK_TOKEN} &&" >>/start
RUN echo "./ngrok tcp --region ap 22 &>/dev/null &" >>/start
RUN mkdir /run/sshd
RUN echo '/usr/sbin/sshd -D' >>/start
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config 
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
RUN echo root:choco|chpasswd
RUN service ssh start
RUN chmod 755 /start

# Add a simple web server for Render to detect
RUN echo '#!/bin/bash' > /web-server.sh
RUN echo 'echo "SSH access via Ngrok - check logs for connection details"' > /index.html
RUN echo 'while true; do { echo -e "HTTP/1.1 200 OK\r\n"; cat /index.html; } | nc -l -p ${PORT:-10000}; done' >> /web-server.sh
RUN chmod +x /web-server.sh

# Expose ports (including Render's default PORT)
EXPOSE 80 8888 8080 443 5130 5131 5132 5133 5134 5135 3306 ${PORT:-10000}

# Start both services
CMD /start & /web-server.sh
