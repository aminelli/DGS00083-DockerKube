@echo off

docker run -it --name deb06 --hostname deb06 --mount type=tmpfs,dst=/app/cache debian:latest /bin/bash



