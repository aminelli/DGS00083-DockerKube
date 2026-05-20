#!/bin/bash

helm repo add portainer https://portainer.github.io/k8s/
helm repo update

# ====================================
# Con esposisizione NodePort
# ====================================

# deploy
helm upgrade --install --create-namespace -n portainer portainer portainer/portainer --set tls.force=true --set image.tag=lts
# port-forward
kubectl -n portainer port-forward svc/portainer 9000:9443
# ====================================


# Disinstallazione
helm uninstall portainer -n portainer
kubectl delete namespace portainer




# nota:
# https://localhost:30779/ or http://localhost:30777/

# https://localhost:9443/ or http://localhost:30776/

# Release "portainer" does not exist. Installing it now.
# NAME: portainer
# LAST DEPLOYED: Wed May 20 12:50:49 2026
# NAMESPACE: portainer
# STATUS: deployed
# REVISION: 1
# DESCRIPTION: Install complete
# NOTES:
# Get the application URL by running these commands:
# export NODE_PORT=$(kubectl get --namespace portainer -o jsonpath="{.spec.ports[1].nodePort}" services portainer)
# export NODE_IP=$(kubectl get nodes --namespace portainer -o jsonpath="{.items[0].status.addresses[0].address}")
# echo https://$NODE_IP:$NODE_PORT