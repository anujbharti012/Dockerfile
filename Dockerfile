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

# Render specific configuration - PORT is required by Render
ENV PORT=8080

# Create a simple web server to satisfy Render's port detection requirements
RUN echo '#!/bin/bash' > /web.sh && \
    echo 'echo "Starting simple web server on port 8080"' >> /web.sh && \
    echo 'mkdir -p /var/www/html' >> /web.sh && \
    echo 'echo "<html><body><h1>Service is running</h1><p>SSH tunnel is active.</p></body></html>" > /var/www/html/index.html' >> /web.sh && \
    echo 'cd /var/www/html && python3 -m http.server $PORT &' >> /web.sh && \
    chmod +x /web.sh

# Create start script with proper line breaks
RUN echo '#!/bin/bash' > /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start web server for Render' >> /start.sh && \
    echo '/web.sh' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Configure ngrok with auth token' >> /start.sh && \
    echo 'if [ -z "$NGROK_TOKEN" ]; then' >> /start.sh && \
    echo '  echo "Error: NGROK_TOKEN is not set. Please set it in your environment variables."' >> /start.sh && \
    echo '  exit 1' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start ngrok in the background' >> /start.sh && \
    echo './ngrok config add-authtoken ${NGROK_TOKEN}' >> /start.sh && \
    echo './ngrok tcp --region ap 22 &' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Wait for ngrok to establish connection' >> /start.sh && \
    echo 'sleep 5' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start SSH server' >> /start.sh && \
    echo '/usr/sbin/sshd -D' >> /start.sh && \
    chmod +x /start.sh

# Expose required ports (8080 is critical for Render)
EXPOSE 8080 22

# Run the start script
CMD ["/start.sh"]
