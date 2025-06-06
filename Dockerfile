FROM ubuntu:22.04

# Basic system setup
RUN apt-get -y update && apt-get -y upgrade && apt-get install -y sudo gnupg
RUN sudo apt-get install -y curl ffmpeg git locales nano python3-pip screen ssh unzip wget  
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash -
RUN sudo apt-get install -y nodejs
ENV LANG en_US.utf8

# Install playit.gg (corrected commands from the image)
RUN curl -SsL https://playit-cloud.github.io/ppa/key.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/playit.gpg >/dev/null
RUN echo "deb [signed-by=/etc/apt/trusted.gpg.d/playit.gpg] https://playit-cloud.github.io/ppa/data ./" | sudo tee /etc/apt/sources.list.d/playit-cloud.list
RUN sudo apt update && sudo apt install -y playit

# SSH setup
RUN mkdir /run/sshd
RUN echo '/usr/sbin/sshd -D' >>/start
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config 
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
RUN echo root:kaal|chpasswd
RUN service ssh start

# Configure playit to automatically tunnel SSH
RUN echo "playit --accept-allocations &" >>/start
RUN echo "sleep 10" >>/start  # Give playit time to start and allocate address
RUN chmod 755 /start

EXPOSE 80 8888 8080 443 5130 5131 5132 5133 5134 5135 3306
CMD /start
