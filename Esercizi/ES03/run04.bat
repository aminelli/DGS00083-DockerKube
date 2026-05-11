@echo off

docker run -it --name deb04 --hostname deb04 -v vol_logs:/logs/ debian:latest /bin/bash


