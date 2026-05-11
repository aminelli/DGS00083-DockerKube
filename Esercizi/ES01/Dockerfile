FROM debian:latest

# Aggiorna i metadati dei repositori
RUN apt-get update

RUN apt-get install -y \
    net-tools \
    iputils-ping \
    iproute2 \
    nano \
    htop \
    curl \
    wget

CMD [ "/bin/bash" ]

