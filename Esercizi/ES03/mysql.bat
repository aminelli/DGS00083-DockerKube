@ echo off

docker volume create vol-mysql-db


docker run -d --name mysql --hostname mysqldb -p 3306:3306 -e MYSQL_ROOT_PASSWORD=123456 -v vol-mysql-db:/var/lib/mysql mysql:latest 