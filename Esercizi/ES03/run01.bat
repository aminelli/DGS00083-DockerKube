@echo off

docker run -it --name deb01 --hostname deb01 -v ./logs/:/tmp/logs/ debian:latest /bin/bash


