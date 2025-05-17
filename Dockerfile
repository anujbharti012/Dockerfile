FROM ubuntu:22.04

# Avoid user interaction during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update and install packages in a single RUN to reduce layers
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y sudo curl ffmpeg git locales nano python3-pip screen ssh unzip wget tzdata && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
    curl -sL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV TZ=UTC

# Set up ngrok
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -q -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip && \
    chmod +x ngrok

# Configure SSH
RUN mkdir -p /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo root:choco | chpasswd

# Create healthcheck script
RUN echo '#!/bin/bash\necho "Server is running!"' > /healthcheck.sh && \
    chmod +x /healthcheck.sh

# Create startup script with better error handling
RUN echo '#!/bin/bash\n\
# Configure ngrok with auth token\n\
if [ -z "$NGROK_TOKEN" ]; then\n\
  echo "Error: NGROK_TOKEN is not set. Please set it in your environment variables."\n\
  exit 1\n\
fi\n\
\n\
# Start ngrok in the background\n\
./ngrok config add-authtoken ${NGROK_TOKEN}\n\
./ngrok tcp --region ap 22 --log=stdout > /var/log/ngrok.log 2>&1 &\n\
\n\
# Wait for ngrok to establish connection\n\
sleep 5\n\
\n\
# Print ngrok tunnel information\n\
curl -s http://localhost:4040/api/tunnels | grep -o "\"public_url\":\"[^\"]*\"" | sed "s/\"public_url\":\"/SSH Access: /g" | sed "s/\"//g"\n\
\n\
# Start SSH server\n\
/usr/sbin/sshd -D\n\
' > /start.sh && \
    chmod +x /start.sh

# Expose ports
EXPOSE 22 80 443 3306 4040 8080 8888 5130-5135

# Set healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 CMD /healthcheck.sh

# Set the entrypoint
CMD ["/start.sh"]
