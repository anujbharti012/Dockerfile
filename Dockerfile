FROM ubuntu:22.04

# Install base dependencies
RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get install -y sudo curl ffmpeg git locales nano python3-pip screen ssh unzip wget

# Set up locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install Node.js
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs

# Set up SSH
RUN mkdir /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo root:choco | chpasswd

# Install and configure Ngrok
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip

# Create start script
RUN echo "#!/bin/bash" > /start && \
    echo "./ngrok config add-authtoken \${NGROK_TOKEN} &&" >> /start && \
    echo "./ngrok tcp --region ap 22 &>/dev/null &" >> /start && \
    echo "/usr/sbin/sshd -D &" >> /start && \
    echo "# Start simple HTTP server for Render port binding" >> /start && \
    echo "python3 -m http.server 8080 --bind 0.0.0.0 &" >> /start && \
    echo "# Keep container running" >> /start && \
    echo "tail -f /dev/null" >> /start && \
    chmod 755 /start

# Expose all requested ports
EXPOSE 22 80 443 8080 5130 5131 5132 5133 5134 5135 3306

# Health check (optional but recommended)
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

CMD ["/start"]
