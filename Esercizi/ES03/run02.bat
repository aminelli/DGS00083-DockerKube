@echo off

docker run -it --name deb02 --hostname deb02 -v ./logs/:/myfolder/logs/ debian:latest /bin/bash


