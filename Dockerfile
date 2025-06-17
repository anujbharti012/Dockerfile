FROM ubuntu:22.04

# Install packages
RUN apt-get -y update && apt-get -y upgrade
RUN apt-get install -y curl ffmpeg git locales nano python3-pip screen ssh unzip wget tmux supervisor

# Setup locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install Node.js
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash -
RUN apt-get install -y nodejs

# Setup ngrok
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
RUN unzip ngrok.zip && chmod +x ngrok

# SSH configuration
RUN mkdir -p /run/sshd /var/log/supervisor
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
RUN echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
RUN echo 'ClientAliveInterval 30' >> /etc/ssh/sshd_config
RUN echo 'ClientAliveCountMax 6' >> /etc/ssh/sshd_config
RUN echo 'X11Forwarding no' >> /etc/ssh/sshd_config
RUN echo root:choco|chpasswd

# Create supervisor config
RUN echo '[supervisord]' > /etc/supervisor/conf.d/supervisord.conf
RUN echo 'nodaemon=true' >> /etc/supervisor/conf.d/supervisord.conf
RUN echo 'user=root' >> /etc/supervisor/conf.d/supervisord.conf
RUN echo '' >> /etc/supervisor/conf.d/supervisord.conf
RUN echo '[program:sshd]' >> /etc/supervisor/conf.d/supervisord.conf
RUN echo 'command=/usr/sbin/sshd -D' >> /etc/supervisor/conf.d/supervisord.conf
RUN echo 'autostart=true' >> /etc/supervisor/conf.d/supervisord.conf
RUN echo 'autorestart=true' >> /etc/supervisor/conf.d/supervisord.conf
RUN echo '' >> /etc/supervisor/conf.d/supervisord.conf
RUN echo '[program:ngrok]' >> /etc/supervisor/conf.d/supervisord.conf
RUN echo 'command=/bin/bash -c "if [ -n \"$NGROK_TOKEN\" ]; then ./ngrok config add-authtoken $NGROK_TOKEN && ./ngrok tcp --region ap 22; else sleep infinity; fi"' >> /etc/supervisor/conf.d/supervisord.conf
RUN echo 'autostart=true' >> /etc/supervisor/conf.d/supervisord.conf
RUN echo 'autorestart=true' >> /etc/supervisor/conf.d/supervisord.conf
RUN echo '' >> /etc/supervisor/conf.d/supervisord.conf
RUN echo '[program:webserver]' >> /etc/supervisor/conf.d/supervisord.conf
RUN echo 'command=python3 -m http.server %(ENV_PORT)s --bind 0.0.0.0' >> /etc/supervisor/conf.d/supervisord.conf
RUN echo 'autostart=true' >> /etc/supervisor/conf.d/supervisord.conf
RUN echo 'autorestart=true' >> /etc/supervisor/conf.d/supervisord.conf

EXPOSE 22 8000
ENV PORT=8000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
