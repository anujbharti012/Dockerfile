FROM ubuntu:22.04

# Install all packages (unchanged)
RUN apt-get -y update && apt-get -y upgrade -y && apt-get install -y sudo
RUN sudo apt-get install -y curl ffmpeg git locales nano python3-pip screen ssh unzip wget  
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash -
RUN sudo apt-get install -y nodejs
ENV LANG en_US.utf8

# Updated Ngrok setup (removed --region flag completely)
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
RUN unzip ngrok.zip
RUN echo "./ngrok config add-authtoken ${NGROK_TOKEN} &&" >>/start
RUN echo "./ngrok tcp 22 &>/dev/null &" >>/start  # Removed deprecated --region flag completely
RUN mkdir /run/sshd
RUN echo '/usr/sbin/sshd -D' >>/start
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config 
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
RUN echo root:choco|chpasswd
RUN service ssh start
RUN chmod 755 /start

# Fixed Python server with proper environment variable handling
RUN echo 'from http.server import BaseHTTPRequestHandler, HTTPServer' > /server.py
RUN echo 'import os' >> /server.py
RUN echo 'class Handler(BaseHTTPRequestHandler):' >> /server.py
RUN echo '    def do_GET(self):' >> /server.py
RUN echo '        self.send_response(200)' >> /server.py
RUN echo '        self.end_headers()' >> /server.py
RUN echo '        self.wfile.write(b"SSH service active")' >> /server.py
RUN echo 'def run(server_class=HTTPServer, handler_class=Handler):' >> /server.py
RUN echo '    port = int(os.environ.get("PORT", 10000))' >> /server.py  # Correct environment variable access
RUN echo '    server_address = ("0.0.0.0", port)' >> /server.py
RUN echo '    httpd = server_class(server_address, handler_class)' >> /server.py
RUN echo '    print(f"Server started on port {port}")' >> /server.py
RUN echo '    httpd.serve_forever()' >> /server.py
RUN echo 'if __name__ == "__main__":' >> /server.py
RUN echo '    run()' >> /server.py

EXPOSE 80 8888 8080 443 5130 5131 5132 5133 5134 5135 3306 ${PORT:-10000}

CMD /start & python3 /server.py
