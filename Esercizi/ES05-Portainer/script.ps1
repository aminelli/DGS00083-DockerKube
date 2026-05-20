
helm repo add portainer https://portainer.github.io/k8s/
helm repo update

helm upgrade --install --create-namespace -n portainer portainer portainer/portainer --set image.tag=lts


# nota:
# https://localhost:30779/ or http://localhost:30777/