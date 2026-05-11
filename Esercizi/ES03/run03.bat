@echo off

docker run -it --name deb03 --hostname deb03 -v vol_logs:/logs/ debian:latest /bin/bash


