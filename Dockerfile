FROM ubuntu:22.04

# Keep all original package installations
RUN apt-get -y update && apt-get -y upgrade -y && apt-get install -y sudo
RUN sudo apt-get install -y curl ffmpeg git locales nano python3-pip screen ssh unzip wget  
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash -
RUN sudo apt-get install -y nodejs
ENV LANG en_US.utf8

# Original Ngrok setup with SSH - with improved terminal access
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
RUN unzip ngrok.zip
RUN echo "#!/bin/bash" > /start.sh
RUN echo "./ngrok config add-authtoken ${NGROK_TOKEN}" >> /start.sh
RUN echo "./ngrok tcp 22 --log=stdout &" >> /start.sh
RUN echo "sleep 5" >> /start.sh
RUN echo "echo '=== NGROK TUNNEL ADDRESS ==='" >> /start.sh
RUN echo "curl -s localhost:4040/api/tunnels | grep -o 'tcp://[^\"]*'" >> /start.sh
RUN echo "echo '==========================='" >> /start.sh
RUN echo "/usr/sbin/sshd -D" >> /start.sh
RUN chmod +x /start.sh

# SSH setup (unchanged)
RUN mkdir /run/sshd
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config 
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
RUN echo root:choco|chpasswd

# SUPER minimal web server - just 3 lines of Python!
RUN echo 'import os; from http.server import SimpleHTTPRequestHandler as Handler; from socketserver import TCPServer as Server' > /server.py
RUN echo 'Server(("0.0.0.0", int(os.getenv("PORT", 10000))), Handler).serve_forever()' >> /server.py

EXPOSE 80 8888 8080 443 5130 5131 5132 5133 5134 5135 3306 ${PORT:-10000}

# Start both services
CMD /start.sh & python3 /server.py
