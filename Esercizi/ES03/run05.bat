@echo off

docker run -it --name deb05 --hostname deb05 -v vol_logs:/app/logs/ -v vol_json:/app/json/ debian:latest /bin/bash

rem Alternativa
docker run -it --name deb05 --hostname deb05 --mount type=volume,source=vol_logs,target=/app/logs --mount type=volume,src=vol_json,dst=/app/json debian:latest /bin/bash
