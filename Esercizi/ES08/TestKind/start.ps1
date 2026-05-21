  docker run -d --name nginx-proxy --hostname nginx-proxy -p 8080:80 -v ./nginx.conf:/etc/nginx/nginx.conf:ro --network kind nginx:latest
  

