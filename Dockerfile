FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update and install base packages
RUN apt-get -y update && apt-get -y upgrade && apt-get install -y \
    sudo \
    curl \
    ffmpeg \
    git \
    locales \
    nano \
    python3-pip \
    screen \
    ssh \
    unzip \
    wget \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Set up locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install Node.js 21.x
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Set up ngrok
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip && \
    chmod +x ngrok

# Setup SSH
RUN mkdir -p /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'root:choco' | chpasswd

# Create startup script with proper error handling
RUN cat > /start << 'EOF'
#!/bin/bash
set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting container initialization..."

# Setup ngrok if token is provided
if [ -n "$NGROK_TOKEN" ]; then
    log "Setting up ngrok..."
    ./ngrok config add-authtoken ${NGROK_TOKEN}
    ./ngrok tcp --region ap 22 --log stdout > /tmp/ngrok.log 2>&1 &
    
    # Wait for ngrok to start and get the public URL
    sleep 10
    
    if curl -s localhost:4040/api/tunnels > /tmp/tunnels.json 2>/dev/null; then
        PUBLIC_URL=$(cat /tmp/tunnels.json | jq -r '.tunnels[0].public_url // empty' 2>/dev/null)
        if [ -n "$PUBLIC_URL" ] && [ "$PUBLIC_URL" != "null" ]; then
            SSH_COMMAND=$(echo "$PUBLIC_URL" | sed 's/tcp:\/\//ssh root@/')
            log "SSH login command: $SSH_COMMAND"
        else
            log "Warning: Could not retrieve ngrok public URL"
        fi
    else
        log "Warning: ngrok API not accessible"
    fi
else
    log "No NGROK_TOKEN provided, skipping ngrok setup"
fi

# Start SSH daemon
log "Starting SSH daemon..."
/usr/sbin/sshd -D &

# Start HTTP server for health checks
log "Starting HTTP server on port ${PORT:-8080}..."
python3 -m http.server ${PORT:-8080} --bind 0.0.0.0 &

log "Container ready!"

# Keep the container running
while true; do
    sleep 30
    # Check if processes are still running
    if ! pgrep -f "python3 -m http.server" > /dev/null; then
        log "HTTP server died, restarting..."
        python3 -m http.server ${PORT:-8080} --bind 0.0.0.0 &
    fi
    if ! pgrep sshd > /dev/null; then
        log "SSH daemon died, restarting..."
        /usr/sbin/sshd -D &
    fi
done
EOF

# Make startup script executable
RUN chmod +x /start

# Set environment variables
ENV PORT=8080

# Expose ports
EXPOSE 22 80 443 3306 5130 5131 5132 5133 5134 5135 8080 8888

# Health check for VPS platforms
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8080}/ || exit 1

# Run the startup script
CMD ["/start"]
