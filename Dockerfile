FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y sudo curl ffmpeg git locales nano python3-pip screen ssh unzip wget python3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs

# Create directory for SSH service
RUN mkdir -p /run/sshd

# Configure SSH
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo root:choco | chpasswd

# Download and setup ngrok
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip && \
    chmod +x ngrok

# Create startup script with proper error handling
COPY <<'EOT' /start.sh
#!/bin/bash
if [ -z "$NGROK_TOKEN" ]; then
  echo "Error: NGROK_TOKEN is not set. Please set it in your Render environment variables."
  exit 1
fi

# Start a simple web server on the PORT Render assigns (for health checks)
if [ -n "$PORT" ]; then
  echo "Starting web server on PORT ${PORT}..."
  python3 -c "
import http.server
import socketserver
import os
import threading

PORT = int(os.environ.get('PORT', 10000))

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(b'SSH Server is running. Use the ngrok tunnel to connect.')

def run_server():
    with socketserver.TCPServer(('', PORT), Handler) as httpd:
        print(f'Serving HTTP on port {PORT}')
        httpd.serve_forever()

thread = threading.Thread(target=run_server)
thread.daemon = True
thread.start()
" &
else
  echo "Warning: PORT environment variable not set by Render"
fi

# Configure and start ngrok
./ngrok config add-authtoken ${NGROK_TOKEN}
./ngrok tcp --region ap 22 --log=stdout &

echo "ngrok started, waiting for tunnel URL..."
# Give ngrok time to start and create the API
sleep 10
# Try to get the tunnel URL
if curl -s http://localhost:4040/api/tunnels | grep -q "tcp://"; then
  echo "Your SSH tunnel is ready:"
  curl -s http://localhost:4040/api/tunnels | grep -o "tcp://[^\"]*"
else
  echo "Warning: Could not get ngrok tunnel URL. Check logs."
fi

echo "Starting SSH server..."
/usr/sbin/sshd -D
EOT

RUN chmod +x /start.sh

# Expose necessary ports
EXPOSE 22 80 443 3306 4040 8080 8888 5130 5131 5132 5133 5134 5135

# Define healthcheck to ensure container is running properly
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD pgrep sshd || exit 1

CMD ["/start.sh"]
