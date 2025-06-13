FROM ubuntu:22.04

# Set environment variables early
ENV LANG=en_US.utf8
ENV DEBIAN_FRONTEND=noninteractive
ENV PORT=8080

# Accept build argument
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}

# Combine package installation and cleanup in single layer
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
        curl \
        ffmpeg \
        git \
        jq \
        locales \
        nano \
        python3-pip \
        screen \
        ssh \
        sudo \
        unzip \
        wget \
        ca-certificates \
        gnupg \
        lsb-release && \
    # Setup locale
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
    # Add NodeSource repository and install Node.js
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_21.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y nodejs && \
    # Install and setup ngrok
    wget -q -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip -q ngrok.zip && \
    rm ngrok.zip && \
    chmod +x ngrok && \
    mv ngrok /usr/local/bin/ && \
    # Setup SSH
    mkdir -p /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'root:choco' | chpasswd && \
    # Clean up apt cache to reduce image size
    apt-get autoremove -y && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create optimized startup script
RUN echo '#!/bin/bash' > /start && \
    echo 'set -e' >> /start && \
    echo '' >> /start && \
    echo '# Function to log with timestamp' >> /start && \
    echo 'log() {' >> /start && \
    echo '    echo "[$(date +'\''%Y-%m-%d %H:%M:%S'\')] $1"' >> /start && \
    echo '}' >> /start && \
    echo '' >> /start && \
    echo '# Setup ngrok if token is provided' >> /start && \
    echo 'if [ -n "$NGROK_TOKEN" ]; then' >> /start && \
    echo '    log "Setting up ngrok..."' >> /start && \
    echo '    ngrok config add-authtoken "${NGROK_TOKEN}"' >> /start && \
    echo '    ngrok tcp --region ap 22 >/dev/null 2>&1 &' >> /start && \
    echo '    ' >> /start && \
    echo '    # Wait for ngrok to start and get the public URL' >> /start && \
    echo '    log "Starting ngrok tunnel..."' >> /start && \
    echo '    sleep 8' >> /start && \
    echo '    ' >> /start && \
    echo '    # Get and display SSH connection info' >> /start && \
    echo '    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then' >> /start && \
    echo '        PUBLIC_URL=$(curl -s localhost:4040/api/tunnels 2>/dev/null | jq -r '\''.tunnels[0].public_url // empty'\'' 2>/dev/null)' >> /start && \
    echo '        if [ -n "$PUBLIC_URL" ]; then' >> /start && \
    echo '            SSH_CMD=$(echo "$PUBLIC_URL" | sed '\''s|tcp://|ssh root@|'\'' | sed '\''s|:| -p |'\'')' >> /start && \
    echo '            log "SSH connection command: $SSH_CMD"' >> /start && \
    echo '        else' >> /start && \
    echo '            log "Could not retrieve ngrok tunnel URL. Check ngrok status manually."' >> /start && \
    echo '        fi' >> /start && \
    echo '    fi' >> /start && \
    echo 'else' >> /start && \
    echo '    log "No NGROK_TOKEN provided, skipping ngrok setup"' >> /start && \
    echo 'fi' >> /start && \
    echo '' >> /start && \
    echo '# Start SSH daemon' >> /start && \
    echo 'log "Starting SSH daemon..."' >> /start && \
    echo '/usr/sbin/sshd -D &' >> /start && \
    echo '' >> /start && \
    echo '# Start HTTP server for health checks' >> /start && \
    echo 'log "Starting HTTP server on port ${PORT:-8080}..."' >> /start && \
    echo 'exec python3 -m http.server "${PORT:-8080}" --bind 0.0.0.0' >> /start

# Make startup script executable
RUN chmod +x /start

# Expose ports (consolidated and organized)
EXPOSE 22 80 443 3306 5130-5135 8080 8888

# Use exec form for better signal handling
CMD ["/start"]
