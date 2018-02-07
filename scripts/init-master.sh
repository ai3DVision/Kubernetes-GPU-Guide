#!/bin/sh
# Give reachable IP as an argument for this script

echo "Publick IP, that will be advertised is: ${1}"
sudo bash -c 'apt-get update && apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF'

sudo apt-get update
sudo apt-get install -y docker.io
sudo apt-get install -y --allow-unauthenticated kubelet kubeadm kubectl kubernetes-cni
sudo groupadd docker
sudo usermod -aG docker $USER

sudo systemctl enable docker && systemctl start docker
sudo systemctl enable kubelet && systemctl start kubelet

echo 'You might need to reboot / relogin to make docker work correctly'

for file in /etc/systemd/system/kubelet.service.d/*-kubeadm.conf
do
    echo "Found ${file}"
    FILE_NAME=$file
done

echo "Chosen ${FILE_NAME} as kubeadm.conf"
sudo sed -i '/^ExecStart=\/usr\/bin\/kubelet/ s/$/ --feature-gates="Accelerators=true"/' ${FILE_NAME}

sudo systemctl daemon-reload
sudo systemctl restart kubelet

sudo kubeadm init --apiserver-advertise-address=$1
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config

kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')" > /dev/null 2>> error.log
kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml > /dev/null 2>> error.log
kubectl create -f ../yaml/admin-user.yaml > /dev/null 2>> error.log
kubectl create -f ../yaml/admin-user-role.yaml > /dev/null 2>> error.log
token=$(kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}') | awk '$1=="token:"{print $2}')

echo "Use the following token to get Dashboard access:"
echo $token
