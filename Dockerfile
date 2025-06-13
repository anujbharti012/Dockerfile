FROM ubuntu:22.04

# Base system setup
RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get install -y sudo curl ffmpeg git locales nano python3-pip screen ssh unzip wget

# Configure locale and language
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install Node.js
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs

# Install jq for JSON parsing
RUN apt-get install -y jq

# Ngrok setup
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip

# SSH configuration
RUN mkdir -p /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'PermitEmptyPasswords no' >> /etc/ssh/sshd_config && \
    echo 'UsePAM yes' >> /etc/ssh/sshd_config && \
    echo 'X11Forwarding yes' >> /etc/ssh/sshd_config && \
    echo 'PrintMotd yes' >> /etc/ssh/sshd_config && \
    echo root:choco | chpasswd && \
    chsh -s /bin/bash root

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Start SSH service\n\
/usr/sbin/sshd\n\
\n\
# Start ngrok if token exists\n\
if [ -n "$NGROK_TOKEN" ]; then\n\
  ./ngrok config add-authtoken ${NGROK_TOKEN} || echo "Ngrok authtoken failed"\n\
  ./ngrok tcp --region ap 22 &>/dev/null &\n\
  sleep 5\n\
  echo "SSH login command:"\n\
  curl -s localhost:4040/api/tunnels | jq -r ".tunnels[0].public_url" | sed "s/tcp:\\/\\//ssh root@/" || echo "Ngrok tunnel failed"\n\
fi\n\
\n\
# Start health check server\n\
python3 -m http.server ${PORT:-8080} --bind 0.0.0.0 &\n\
\n\
# Keep container alive\n\
tail -f /dev/null' > /start && \
    chmod 755 /start

# Configure user environment
RUN echo "export TERM=xterm" >> /root/.bashrc && \
    echo "cd ~" >> /root/.bashrc && \
    echo "echo 'Welcome to SSH session'" >> /root/.bashrc

# Expose ports
EXPOSE 22 80 443 3306 5130 5131 5132 5133 5134 5135 8080 8888

# Set default PORT
ENV PORT=8080

# Start command
CMD ["/start"]
