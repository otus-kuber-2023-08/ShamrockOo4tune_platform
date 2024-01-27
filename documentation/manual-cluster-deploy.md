## On local machine

```bash
tf apply -var ceph=false -var workers_qty=1 -var masters_qty=1

tf output -json > outputs.json
export BASTION_IP=$(cat outputs.json | jq -r .bastion_public_ip.value)
scp    -o "StrictHostKeyChecking no" -i ansible_rsa ansible_rsa  ansible@$BASTION_IP:/home/ansible/.ssh/id_rsa || true
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sudo apt-get -y update && sudo DEBIAN_FRONTEND=noninteractive apt-get -y install software-properties-common gnupg2 git curl python3-pip ansible-core jq; sudo mkdir -p /root/ansible; sudo touch /root/ansible/ansible.log"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sudo add-apt-repository -y ppa:deadsnakes/ppa"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sudo DEBIAN_FRONTEND=noninteractive apt-get -y install python3.11"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 2 && sudo update-alternatives --config python3"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && sudo python3 get-pip.py; sudo pip install virtualenv; pip install ansible-core; sudo pip install -Iv 'resolvelib<0.6.0'"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "cd; git clone https://github.com/kubernetes-sigs/kubespray.git; cd kubespray; cp -rfp inventory/sample inventory/mycluster"
scp    -o "StrictHostKeyChecking no" -i ansible_rsa ../k8s/hosts.yaml      ansible@$BASTION_IP:/home/ansible/kubespray/inventory/mycluster/hosts.yaml
scp    -o "StrictHostKeyChecking no" -i ansible_rsa ../k8s/addons.yml.template      ansible@$BASTION_IP:/home/ansible/kubespray/inventory/mycluster/group_vars/k8s_cluster/addons.yml.template
scp    -o "StrictHostKeyChecking no" -i ansible_rsa ../k8s/k8s-cluster.yml.template ansible@$BASTION_IP:/home/ansible/kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml.template
scp    -o "StrictHostKeyChecking no" -i ansible_rsa outputs.json ansible@$BASTION_IP:/home/ansible/outputs.json
scp -r -o "StrictHostKeyChecking no" -i ansible_rsa ../argocd ansible@$BASTION_IP:/home/ansible/argocd
ssh    -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP
```  

<br>  

## On bastion

### k8s base
```bash
cd kubespray
vi inventory/mycluster/hosts.yaml 

export ARGOCD_ADMIN_PASSWORD=ytnybr
export PLATFORM_INGRESS_IP=$(cat ~/outputs.json | jq -r .platform_ingress_ip.value)
envsubst '$ARGOCD_ADMIN_PASSWORD' < inventory/mycluster/group_vars/k8s_cluster/addons.yml.template > inventory/mycluster/group_vars/k8s_cluster/addons.yml
envsubst '$PLATFORM_INGRESS_IP'   < inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml.template > inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml

sudo virtualenv ../kubespray; source bin/activate; sudo pip install -r requirements.txt; sudo ansible-playbook -i inventory/mycluster/hosts.yaml --become --become-user=root --user=ansible --key-file=/home/ansible/.ssh/id_rsa cluster.yml; deactivate
```  

### kubectl

```bash
sudo cp /home/ansible/kubespray/inventory/mycluster/artifacts/kubectl /usr/local/bin/
mkdir -p ~/.kube
sudo cp /home/ansible/kubespray/inventory/mycluster/artifacts/admin.conf ~/.kube/config
sudo chown ansible:ansible ~/.kube/config
sudo apt-get install -y bash-completion
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "alias k=kubectl" >> ~/.bashrc
echo "complete -o default -F __start_kubectl k" >> ~/.bashrc
. ~/.bashrc

k get nodes -o wide
```

### Istio
```bash
k label namespace argocd istio-injection=enabled
k -n argocd patch cm argocd-cmd-params-cm --patch-file ~/argocd/argo-patch.yaml
k -n argocd scale deployment argocd-server --replicas=0 && sleep 5 && k -n argocd scale deployment argocd-server --replicas=1 && sleep 30
k apply -f /home/ansible/argocd/root-projects.yaml 
k apply -f /home/ansible/argocd/root-applications.yaml
```  

### ArgoCD cmd-line tool

```bash
VERSION=v2.8.4 
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```  

### local kubeconfig

```bash
scp    -o "StrictHostKeyChecking no" -i ansible_rsa ansible@$BASTION_IP:/home/ansible/.kube/config ~/.kube/yconfig
export INGRESS_IP=$(cat outputs.json | jq -r .platform_ingress_ip.value)
export MASTER1_IP=$(cat outputs.json | jq -r .master_nodes_private_ips.value[0])
sed -i "s/$MASTER1_IP/$INGRESS_IP/" ~/.kube/yconfig
alias k="kubectl --kubeconfig ~/.kube/yconfig"
```

### Access ArgoCD UI

On local machine, in separate terminal session:  
```bash
sudo kubectl --kubeconfig ~/.kube/yconfig port-forward svc/argocd-server -n argocd 8080:443
```  

web ui available locally on https://localhost:8080

### Access ArgoCD CLI

```bash
argocd login localhost:8080 --insecure --username admin --password < пароль > --name project

argocd app create root-app \
    --dest-namespace argocd \
    --dest-server https://kubernetes.default.svc \
    --repo https://github.com/otus-kuber-2023-08/ShamrockOo4tune_platform.git \
    --path kubernetes-project/argocd/apps \
    --revision kubernetes-prod
argocd app sync root-app  
```  

<br>  
