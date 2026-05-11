@echo off

docker volume create vol_logs
docker run --rm -v vol_logs:/logs/ -v ./backups:/backups alpine tar xzf /backups/backup_001.tar -C /logs 