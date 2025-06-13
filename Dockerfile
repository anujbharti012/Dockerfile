FROM ubuntu:22.04

RUN apt-get -y update && apt-get -y upgrade && apt-get install -y sudo
RUN sudo apt-get install -y curl ffmpeg git locales nano python3-pip screen ssh unzip wget
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash -
RUN sudo apt-get install -y nodejs
ENV LANG en_US.utf8

ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}

# Install ngrok
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
RUN unzip ngrok.zip

# Setup SSH
RUN mkdir -p /run/sshd
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config 
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
RUN echo root:choco|chpasswd

# Create a startup script
RUN echo '#!/bin/bash' > /start
RUN echo 'if [ -n "$NGROK_TOKEN" ]; then' >> /start
RUN echo '  ./ngrok config add-authtoken ${NGROK_TOKEN}' >> /start
RUN echo '  ./ngrok tcp --region ap 22 &>/dev/null &' >> /start
RUN echo '  sleep 5' >> /start
RUN echo '  echo "SSH login command:"' >> /start
RUN echo '  curl -s localhost:4040/api/tunnels | jq -r ".tunnels[0].public_url" | sed "s/tcp:\/\//ssh root@/"' >> /start
RUN echo 'fi' >> /start
RUN echo '/usr/sbin/sshd' >> /start

# Simple HTTP server to keep the container running and respond to Render's health checks
RUN echo 'python3 -m http.server ${PORT:-8080} --bind 0.0.0.0' >> /start
RUN chmod 755 /start

# Install jq for JSON parsing
RUN apt-get install -y jq

# Expose ports
EXPOSE 22 80 443 3306 5130 5131 5132 5133 5134 5135 8080 8888

# Set the PORT environment variable with a default value
ENV PORT=8080

CMD ["/start"]
