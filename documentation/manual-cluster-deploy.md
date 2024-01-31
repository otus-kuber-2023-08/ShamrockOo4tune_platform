## On local machine

```bash
tf apply -var ceph=false -var workers_qty=1 -var masters_qty=1

tf output -json > outputs.json
export BASTION_IP=$(cat outputs.json | jq -r .bastion_public_ip.value)
export PLATFORM_INGRESS_IP=$(cat outputs.json | jq -r .platform_ingress_ip.value)
export MASTER1_IP=$(cat outputs.json | jq -r .master_nodes_private_ips.value[0])
export MASTER2_IP=$(cat outputs.json | jq -r .master_nodes_private_ips.value[1])
export MASTER3_IP=$(cat outputs.json | jq -r .master_nodes_private_ips.value[2])
export WORKER1_IP=$(cat outputs.json | jq -r .worker_nodes_private_ips.value[0])
export WORKER2_IP=$(cat outputs.json | jq -r .worker_nodes_private_ips.value[1])
export WORKER3_IP=$(cat outputs.json | jq -r .worker_nodes_private_ips.value[2])
export CEPH1_IP=$(cat outputs.json | jq -r .ceph1_private_ip.value)
export CEPH2_IP=$(cat outputs.json | jq -r .ceph2_private_ip.value)
export CEPH3_IP=$(cat outputs.json | jq -r .ceph3_private_ip.value)
export ARGOCD_ADMIN_PASSWORD=ytnybr

scp    -o "StrictHostKeyChecking no" -i ansible_rsa ansible_rsa  ansible@$BASTION_IP:/home/ansible/.ssh/id_rsa || true
scp -r -o "StrictHostKeyChecking no" -i ansible_rsa ../ceph   ansible@$BASTION_IP:/home/ansible/ceph
scp -r -o "StrictHostKeyChecking no" -i ansible_rsa ../argocd ansible@$BASTION_IP:/home/ansible/argocd
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sudo apt-get -y update && sudo DEBIAN_FRONTEND=noninteractive apt-get -y install software-properties-common gnupg2 git curl python3-pip ansible-core jq ceph-common; sudo mkdir -p /root/ansible; sudo touch /root/ansible/ansible.log"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sudo add-apt-repository -y ppa:deadsnakes/ppa"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sudo DEBIAN_FRONTEND=noninteractive apt-get -y install python3.11"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 2 && sudo update-alternatives --config python3"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && sudo python3 get-pip.py; sudo pip install virtualenv; pip install ansible-core; sudo pip install -Iv 'resolvelib<0.6.0'"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "git clone https://github.com/ceph/ceph-ansible.git; cd ceph-ansible; git checkout stable-7.0"
for i in 1 2 3 ; do ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sed -i "s/ceph${i}_ip/$(cat outputs.json | jq -r .ceph${i}_private_ip.value)/" ceph/inventory.ini" ; done
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "cp ceph/inventory.ini ceph-ansible/inventory.ini"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "cp ceph/site.yml      ceph-ansible/site.yml"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "cp ceph/all.yml       ceph-ansible/group_vars/all.yml"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "cp ceph/osds.yml      ceph-ansible/group_vars/osds.yml"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "git clone https://github.com/kubernetes-sigs/kubespray.git; cd kubespray; cp -rfp inventory/sample inventory/mycluster"
scp    -o "StrictHostKeyChecking no" -i ansible_rsa ../k8s/hosts.yaml      ansible@$BASTION_IP:/home/ansible/kubespray/inventory/mycluster/hosts.yaml
scp    -o "StrictHostKeyChecking no" -i ansible_rsa ../k8s/addons.yml.template      ansible@$BASTION_IP:/home/ansible/kubespray/inventory/mycluster/group_vars/k8s_cluster/addons.yml.template
scp    -o "StrictHostKeyChecking no" -i ansible_rsa ../k8s/k8s-cluster.yml.template ansible@$BASTION_IP:/home/ansible/kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml.template
scp    -o "StrictHostKeyChecking no" -i ansible_rsa outputs.json ansible@$BASTION_IP:/home/ansible/outputs.json

for i in 1 2 3 ; do
  MASTER_IP=MASTER${i}_IP
  if [ "${!MASTER_IP}" == 'null' ]; then
    echo "INFO: MASTER${i}_IP is 'null', rm it from hosts" 
    ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sed -i '/master${i}/d' ~/kubespray/inventory/mycluster/hosts.yaml"
  else
    echo "INFO: Substituting MASTER${i}_IP in hosts"
    ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sed -i 's/master${i}_ip/${!MASTER_IP}/' ~/kubespray/inventory/mycluster/hosts.yaml"
  fi
  WORKER_IP=WORKER${i}_IP
  if [ "${!WORKER_IP}" == 'null' ]; then
    echo "INFO: WORKER${i}_IP is 'null', rm it from hosts" 
    ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sed -i '/worker${i}/d' ~/kubespray/inventory/mycluster/hosts.yaml"
  else
    echo "INFO: Substituting WORKER${i}_IP in hosts"
    ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sed -i 's/worker${i}_ip/${!WORKER_IP}/' ~/kubespray/inventory/mycluster/hosts.yaml"
  fi
done
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible ${BASTION_IP} ARGOCD_ADMIN_PASSWORD=${ARGOCD_ADMIN_PASSWORD} "envsubst '\${ARGOCD_ADMIN_PASSWORD}' < ~/kubespray/inventory/mycluster/group_vars/k8s_cluster/addons.yml.template > ~/kubespray/inventory/mycluster/group_vars/k8s_cluster/addons.yml"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible ${BASTION_IP} PLATFORM_INGRESS_IP=${PLATFORM_INGRESS_IP} "envsubst '\${PLATFORM_INGRESS_IP}' < ~/kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml.template > ~/kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml"
ssh -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible ${BASTION_IP}
```

### Ceph
On local machine 
```bash
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "cd /home/ansible/ceph-ansible; sudo virtualenv ../ceph-ansible; source bin/activate; sudo pip install 'ansible-core<2.15.5'; sudo pip install -r requirements.txt; sudo ansible-galaxy install -r requirements.yml; sudo ansible-playbook -i inventory.ini ./site.yml; deactivate"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh -o 'StrictHostKeyChecking no' ceph1.ru-central1.internal 'sudo ceph config set mon auth_allow_insecure_global_id_reclaim false'"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh -o 'StrictHostKeyChecking no' ceph1.ru-central1.internal 'sudo ceph -s'"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sudo mkdir -p -m 755 /etc/ceph"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh ceph1.ru-central1.internal 'sudo ceph config generate-minimal-conf' | sudo tee /etc/ceph/ceph.conf"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sudo chmod 644 /etc/ceph/ceph.conf"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh ceph1.ru-central1.internal 'sudo ceph fs authorize cephfs client.kube / rw' | sudo tee /etc/ceph/ceph.client.kube.keyring"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sudo chmod 600 /etc/ceph/ceph.client.kube.keyring"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sudo mkdir -p /mnt/mycephfs"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh ceph1.ru-central1.internal 'sudo ceph auth get-key client.kube' | sudo tee /etc/ceph/kube.key"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sudo chmod 600 /etc/ceph/kube.key"
# ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sudo mount -t ceph kube@.cephfs=/ /mnt/mycephfs -o secretfile=/etc/ceph/kube.key"
export CEPH_FSID=$(ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh ceph1.ru-central1.internal 'sudo ceph fsid'")
export CEPH_ADMIN_KEY=$(ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh ceph1.ru-central1.internal 'sudo ceph auth get client.admin'" | grep 'key = ' | awk '{ print $3 }')
export CEPH_KUBE_KEY=$(ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh ceph1.ru-central1.internal 'sudo ceph auth get-key client.kube'")
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "echo 'kube@.cephfs=/ /mnt/mycephfs ceph mon_addr=ceph1.ru-central1.internal:6789/ceph2.ru-central1.internal:6789/ceph3.ru-central1.internal:6789,secretfile=/etc/ceph/kube.key,noatime,_netdev 0 0' | sudo tee -a /etc/fstab"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "sudo mount /mnt/mycephfs"
ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "df -h"
```

### k8s
On bastion host
```bash
cd kubespray
sudo virtualenv ../kubespray
source bin/activate
sudo pip install -r requirements.txt
sudo ansible-playbook -i inventory/mycluster/hosts.yaml --become --become-user=root --user=ansible --key-file=/home/ansible/.ssh/id_rsa cluster.yml
deactivate"
```  



### Выключить ceph кластер
```bash
for CEPH_NODE in ceph1.ru-central1.internal ceph2.ru-central1.internal ceph3.ru-central1.internal ; do 
  ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh -o 'StrictHostKeyChecking no' ${CEPH_NODE} 'sudo ceph osd set noout'"
  ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh -o 'StrictHostKeyChecking no' ${CEPH_NODE} 'sudo ceph osd set nobackfill'"
  ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh -o 'StrictHostKeyChecking no' ${CEPH_NODE} 'sudo ceph osd set norecover'"
  ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh -o 'StrictHostKeyChecking no' ${CEPH_NODE} 'sudo ceph osd set norebalance'"
  ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh -o 'StrictHostKeyChecking no' ${CEPH_NODE} 'sudo ceph osd set nodown'"
  ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh -o 'StrictHostKeyChecking no' ${CEPH_NODE} 'sudo ceph osd set pause'"
done
```

### Включить ceph кластер
```bash
for CEPH_NODE in ceph1.ru-central1.internal ceph2.ru-central1.internal ceph3.ru-central1.internal ; do 
  ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh -o 'StrictHostKeyChecking no' ${CEPH_NODE} 'sudo ceph osd unset pause'"
  ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh -o 'StrictHostKeyChecking no' ${CEPH_NODE} 'sudo ceph osd unset nodown'"
  ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh -o 'StrictHostKeyChecking no' ${CEPH_NODE} 'sudo ceph osd unset norebalance'"
  ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh -o 'StrictHostKeyChecking no' ${CEPH_NODE} 'sudo ceph osd unset norecover'"
  ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh -o 'StrictHostKeyChecking no' ${CEPH_NODE} 'sudo ceph osd unset nobackfill'"
  ssh -T -o "StrictHostKeyChecking no" -i ansible_rsa -l ansible $BASTION_IP "ssh -o 'StrictHostKeyChecking no' ${CEPH_NODE} 'sudo ceph osd unset noout'"
done
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

### ArgoCD
```bash
export SELECTEL_API_TOKEN=

envsubst '$SELECTEL_API_TOKEN' < /home/ansible/argocd/selectel-api-token.yml.template > /home/ansible/argocd/selectel-api-token.yml
k apply -f /home/ansible/argocd/selectel-api-token.yml
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

k -n argocd annotate service argocd-server-metrics "prometheus.io/scrape=true"