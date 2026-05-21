# Documentazione


## Compilazione

```sh
# Build
docker build -t web_app_spring:v2.0 .

# Tag
docker tag web_app_spring:v2.0 aminelli/web_app_spring:v2.0

# Push su docker hub
docker push aminelli/web_app_spring:v2.0

# Test Esecuzione in un ambiente docker a parte
docker run -d --name webapp --hostname webapp -p 8080:8080 web_app_spring:v2.0

# Rilascio in kubernetes
kubectl apply -f KubeDep.yaml

```