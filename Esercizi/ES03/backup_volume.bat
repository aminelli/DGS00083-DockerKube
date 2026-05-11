@echo off

docker run --rm -v vol_logs:/logs/ -v ./backups:/backups alpine tar czf /backups/backup_001.tar -C /logs .