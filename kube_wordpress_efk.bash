#
#  A "one-liner" example of creating a docker image of word-press and mysql using kubectl
#  Inlcuding ElasticSearch, Kibana and TLS certification
#

# Initialize kube (Docker Playground example)
systemctl start docker.service
kubeadm config images pull
kubeadm init --apiserver-advertise-address $(hostname -i) --pod-network-cidr 10.5.0.0/16
kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter.yaml

kubectl create ns site-wordpress
kubectl create ns cert-manager
kubectl create ns ingress-nginx
kubectl create ns elastic-system
kubectl create ns observability

# Setup Helm and NGINX
# Banzaicloud logging-operator and logging-operator-logging
helm repo add banzaicloud-stable https://kubernetes-charts.banzaicloud.com
helm repo update
helm install logging-operator banzaicloud-stable/logging-operator -n observability \
  --set createCustomResource=false \
  --set rbac.enable=true
# Cert-Manager for TLS Certificates
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager -n cert-manager \
  --namespace cert-manager \
  --version v0.16.1 \
  --set installCRDs=true
# Ingress Nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx

# Add Elastic
kubectl apply -f https://download.elastic.co/downloads/eck/1.2.1/all-in-one.yaml
# Deploy MySQL
password=`date +%s|sha256sum|base64|head -c 32`
kubectl create secret generic mysql-pass password -n site-wordpress
kubectl apply -f manifests/mysql/mysql-sc.yaml -n site-wordpress
kubectl apply -f manifests/mysql/mysql-pvc.yaml -n site-wordpress
kubectl apply -f manifests/mysql/mysql-svc.yaml -n site-wordpress
kubectl apply -f manifests/mysql/mysql-deployment.yaml -n site-wordpress

# Certificate it!
kubectl apply -f manifests/cert-manager/issuer.yaml -n site-wordpress
kubectl apply -f manifests/cert-manager/certificate.yaml -n site-wordpress

# Apply Elastic and Kibana
kubectl create secret generic logging-es-elastic-user --from-literal=elastic=teste -n observability
kubectl apply -f manifests/efk/es-sc.yaml -n observability
kubectl apply -f manifests/efk/es-cluster.yaml -n observability
kubectl apply -f manifests/efk/kibana-eck.yaml -n observability

# Apply logging operators
kubectl apply -f manifests/efk/logging-operator-logging.yaml -n observability
kubectl apply -f manifests/efk/logging-operator-cluster-output.yaml -n observability
kubectl apply -f manifests/efk/logging-operator-flow.yaml -n site-wordpress

# Nobody will know
kubectl delete -k ./