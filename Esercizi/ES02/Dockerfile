FROM scratch

ADD rootfs.tar.gz /

# Aggiorna i metadati dei repositori
RUN apt-get update

# Installazione pacchetti aggiuntivi
RUN apt-get install -y \
    net-tools \
    iputils-ping \
    iproute2 \
    nano \
    htop \
    curl \
    wget

CMD ["/bin/bash"]