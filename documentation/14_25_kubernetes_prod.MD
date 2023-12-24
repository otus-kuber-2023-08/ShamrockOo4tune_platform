# Подходы к развертываниюразвертыванию и обновлению production-grade кластера  

## Подготовка

Цель задания - развернуть кластер версии 1.23 и обновить его.  
Разворачивать кластер буду на виртуальных машинах в Yandex Cloud  
Для этого в облаке выделен отдельный каталог "iac" с id=b1gjap7i9e06sdcbetb4  

<br>  

## Создание нод для кластера

В YC Cоздать 4 ноды с образом Ubuntu 20.04 LTS:  
master - 1 экземпляр (intel ice lake, 2vCPU, 8 GB RAM)  
worker - 3 экземпляра (intel ice lake, 2vCPU, 8 GB RAM)  

Публичный ip адрес назначим только мастеру, для возможности пользоваться 
кластером из интернета. Доступ к worker нодам будем осуществлять с master ноды, 
для возможности с worker закачивать данные из интернет назначим nat шлюз 
(egress).  

Подбор образа с требуемой ос:  
```bash
$ yc compute image list --folder-id standard-images 
+----------------------+----------------------------+-----------------+----------------------+--------+
|          ID          |           NAME             |     FAMILY      |      PRODUCT IDS     | STATUS |
+----------------------+----------------------------+-----------------+----------------------+--------+
| ...                                                                                                 |
| fd85an6q1o26nf37i2nl | ubuntu-20-04-lts-v20231218 | ubuntu-2004-lts | f2ekp29fd7vk7pke4hj5 | READY  |
| ...                                                                                                 |
+----------------------+----------------------------+-----------------+----------------------+--------+
```  

Создание через terraform в [поддиректории iac](/kubernetes-prod/iac/)  

```bash
$ cd kubernetes-prod/iac
$ tf init
$ tf plan 
$ tf apply --auto-approve

...
Outputs:

master_hostname = "master"
master_private_ip = "192.168.10.10"
master_public_ip = "< скрыто >"
worker_nodes_hostnames = [
  "worker-1",
  "worker-2",
  "worker-3",
]
worker_nodes_private_ips = [
  "192.168.10.11",
  "192.168.10.12",
  "192.168.10.13",
]
```  
Для удобного доступа по ssh внесем соответствующие записи в /etc/hosts  
и в ~/.ssh/config:  
```bash
$ cat <<EOF >>~/.ssh/config
Host master
  Hostname < скрыто >
  User ubuntu
  Port 22
  IdentityFile /home/anduser/.ssh/id_rsa
EOF

$ echo '< скрыто > master kubernetes' | sudo tee -a /etc/hosts

$ ssh master
```

SSH доступ на воркеры будет только с мастр ноды, поэтому прописываем хосты и  
добавляем соответствующий ключ ~/.ssh/id_rsa:  
```bash
# на мастер ноде
$ cat <<EOF | sudo tee -a /etc/hosts
192.168.10.10 master
192.168.10.11 worker-1
192.168.10.12 worker-2
192.168.10.13 worker-3
EOF

$ cat <<EOF >>~/.ssh/config
Host worker-1
  Hostname 192.168.10.11
  User ubuntu
  Port 22
  IdentityFile /home/ubuntu/.ssh/id_rsa
Host worker-2
  Hostname 192.168.10.12
  User ubuntu
  Port 22
  IdentityFile /home/ubuntu/.ssh/id_rsa
Host worker-3
  Hostname 192.168.10.13
  User ubuntu
  Port 22
  IdentityFile /home/ubuntu/.ssh/id_rsa
EOF
```  

И на всех ворекерах прописываем hosts c членами кластера  
<br>  

## Подготовка машин

На всех машинах выполняем
```bash
# отключение swap
$ sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
$ sudo swapoff -a
```  

<br>  

## Загрузим br_netfilter, позволим iptables видеть трафик включим forwarding 

```bash
$ cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

$ sudo modprobe overlay
$ sudo modprobe br_netfilter

$ cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-iptables=1 
net.ipv4.ip_forward=1 
net.bridge.bridge-nf-call-ip6tables=1 
EOF

$ sudo sysctl --system
```  

<br>  

##  Установка containerd

```bash
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
$ sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
$ sudo apt update -y
$ sudo apt install -y containerd.io
$ sudo mkdir -p /etc/containerd
$ containerd config default | sudo tee /etc/containerd/config.toml
$ sudo systemctl restart containerd
$ sudo systemctl enable containerd
```  

<br>  

## Установка kubectl, kubeadm, kubelet
```bash
$ sudo apt-get update && sudo apt-get install -y apt-transport-https curl
$ curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
$ echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
$ sudo apt update -y
$ sudo apt -y install vim git curl wget kubelet=1.23.0-00 kubeadm=1.23.0-00 kubectl=1.23.0-00
$ sudo apt-mark hold kubelet kubeadm kubectl
$ sudo kubeadm config images pull --cri-socket /run/containerd/containerd.sock --kubernetes-version v1.23.0
```  

<br>  

## Создание кластера

```bash
$ sudo kubeadm init \
  --apiserver-cert-extra-sans < публичный IP master node >[,< доп. домен или IP >] \
  --pod-network-cidr=10.244.0.0/16 \
  --upload-certs \
  --kubernetes-version=v1.23.0 \
  --cri-socket /run/containerd/containerd.sock
```  

<br>  

## Копируем конфиг kubectl

Cкопировать данные для подключения к кластеру из 
**/etc/kubernetes/admin.conf** мастер ноды и вписать в соответствующие поля 
**~/.kube/config** своей локальной машины.  
Проверка:  
```bash
# c локальной машины
$ k cluster-info 
Kubernetes control plane is running at https://< скрыто >:6443
CoreDNS is running at https://< скрыто >:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
anduser@shamil:~$ k get nodes
NAME     STATUS     ROLES                  AGE     VERSION
master   NotReady   control-plane,master   5m46s   v1.23.0
```  

<br>  

## Установим сетевой плагин

Выбираю плагин [Cilium](https://cilium.io/)  

### Cilium CLI - инструмент командной строки

Устанавку cilium cli и самого cilium выполняем с локального компьютера, 
оттуда же, где настроен **kubectl**  

```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
```

### Cilium
```bash
$ helm repo update
$ cilium install --version 1.14.5
$ cilium status
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    disabled (using embedded mode)
 \__/¯¯\__/    Hubble Relay:       disabled
    \__/       ClusterMesh:        disabled

Deployment             cilium-operator    Desired: 1, Ready: 1/1, Available: 1/1
DaemonSet              cilium             Desired: 1, Ready: 1/1, Available: 1/1
Containers:            cilium-operator    Running: 1
                       cilium             Running: 1
Cluster Pods:          2/2 managed by Cilium
Helm chart version:    1.14.5
Image versions         cilium             quay.io/cilium/cilium:v1.14.5@sha256:d3b287029755b6a47dee01420e2ea469469f1b174a2089c10af7e5e9289ef05b: 1
                       cilium-operator    quay.io/cilium/operator-generic:v1.14.5@sha256:303f9076bdc73b3fc32aaedee64a14f6f44c8bb08ee9e3956d443021103ebe7a: 1
```    

<br>  

## Подключаем worker ноды

Получаем команду для присоединения на мастер ноде:  
```bash
$ sudo kubeadm token create --print-join-command

kubeadm join 192.168.10.10:6443 --token < скрыто > --discovery-token-ca-cert-hash < скрыто >  
```  

Идем на каждый из воркеров и присоединяем их:  
```bash
$ sudo kubeadm join 192.168.10.10:6443 \
  --token < скрыто > \
  --discovery-token-ca-cert-hash < скрыто >
```  

Проверка кластера с локальной машины:  
```bash
$ k get nodes -o wide
NAME       STATUS   ROLES                  AGE     VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
master     Ready    control-plane,master   35m     v1.23.0   192.168.10.10   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.6.26
worker-1   Ready    <none>                 3m53s   v1.23.0   192.168.10.11   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.6.26
worker-2   Ready    <none>                 88s     v1.23.0   192.168.10.12   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.6.26
worker-3   Ready    <none>                 68s     v1.23.0   192.168.10.13   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.6.26
```  

<br>  

## Запуск нагрузки

```bash
$ k create deploy nginx-deployment \
  --replicas=4 \
  --image=nginx:1.17.2

deployment.apps/nginx-deployment created

$ k get pods -o wide
NAME                               READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
nginx-deployment-fc796d66c-fhp65   1/1     Running   0          20s   10.0.2.139   worker-2   <none>           <none>
nginx-deployment-fc796d66c-kpt59   1/1     Running   0          20s   10.0.3.137   worker-3   <none>           <none>
nginx-deployment-fc796d66c-rc224   1/1     Running   0          20s   10.0.1.85    worker-1   <none>           <none>
nginx-deployment-fc796d66c-szvbs   1/1     Running   0          20s   10.0.1.138   worker-1   <none>           <none>
```  

<br>  

## Обновление кластера

Так как кластер создавался kubeadm, то обновлять его будем им же. Сначала 
master, потом - worker ноды.  

### Обновление мастера  
```bash
$ sudo apt update
$ apt-cache madison kubeadm
$ sudo apt-get install kubeadm='1.24.17-00' \
  -y \
  --allow-change-held-packages
$ sudo kubeadm upgrade plan
$ sudo kubeadm upgrade apply v1.24.17
```  

Версия kubelet остается прежней:
```bash
$ k get nodes
NAME       STATUS   ROLES           AGE    VERSION
master     Ready    control-plane   3h9m   v1.23.0
worker-1   Ready    <none>          157m   v1.23.0
worker-2   Ready    <none>          154m   v1.23.0
worker-3   Ready    <none>          154m   v1.23.0
```  

Но версия api сервера (компонентов control plane) поменялась:
```bash
$ k version --short | grep Server
Server Version: v1.24.17
```  

### Обновление kubelet и kubectl на master node

Дренируем нагрузку и обновляем:
```bash
# на локальном компьютере
$ k drain master --ignore-daemonsets

# на master ноде:
$ sudo apt-get install kubelet='1.24.17-00' kubectl='1.24.17-00' \
  -y \
  --allow-change-held-packages 
$ sudo systemctl daemon-reload
$ sudo systemctl restart kubelet

# на локальном компьютере
$ k uncordon master
$ k get nodes

NAME       STATUS   ROLES           AGE     VERSION
master     Ready    control-plane   3h54m   v1.24.17
worker-1   Ready    <none>          3h23m   v1.23.0
worker-2   Ready    <none>          3h20m   v1.23.0
worker-3   Ready    <none>          3h20m   v1.23.0
```

### Обновление worker nodes

Операции выполняем на каждой из worker нод. Обновляем по очереди, сначала 
полностью одну ноду, и, после ее ввода в срой, - обновляем следующую.  

<br>  

Обновляем kubeadm и конфигурации компонентов на ноде:  
```bash
$ sudo apt update
$ apt-cache madison kubeadm
$ sudo apt-get install kubeadm='1.24.17-00' \
  -y \
  --allow-change-held-packages
$ sudo kubeadm upgrade node
```
Дренируем нагрузку и обновляем kubelet
```bash
# на локальном компьютере
$ k drain worker-1 --ignore-daemonsets

# на worker-1
$ sudo apt-get install kubelet='1.24.17-00' kubectl='1.24.17-00' \
  -y \
  --allow-change-held-packages
$ sudo systemctl daemon-reload
$ sudo systemctl restart kubelet

# на локальном компьютере
$ k uncordon worker-1
```  

### Просмотр обновления
```bash
$ k get nodes
NAME       STATUS   ROLES           AGE     VERSION
master     Ready    control-plane   4h23m   v1.24.17
worker-1   Ready    <none>          3h52m   v1.24.17
worker-2   Ready    <none>          3h49m   v1.24.17
worker-3   Ready    <none>          3h49m   v1.24.17
```  

<br>  

## Автоматическое развертывание кластеров

Для выполнения задания буду переиспользовать код развертывания инфраструктуры.  
И заново произведу установку кластера, уже при помощи 
[kubespray](https://github.com/kubernetes-sigs/kubespray).   
Публичный IP адрес будет также только у мастер ноды, поэтому запускать сценарии 
буду с нее.  

## Установка Kubespray

### Пререквизиты - python3 и pip

Удовлетворить требованиям requirements.txt мастер ветки проекта Kubespray, 
используя дистрибутив Ubuntu20.04, оказалось весьма нетривиальной задачей:  
```bash
$ sudo add-apt-repository ppa:deadsnakes/ppa
$ sudo apt-get update
$ sudo apt-get install python3.11
$ sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 2
$ sudo update-alternatives --config python3
# установка pip от рута:
$ sudo -i
# curl https://bootstrap.pypa.io/get-pip.py | python3
# exit

$ python3 -V
Python 3.11.7

$ pip -V
pip 23.3.2 from /home/ubuntu/.local/lib/python3.11/site-packages/pip (python 3.11)

# плюс еще немного "приседаний" в связи с отсутствующим apt_pkg:
$ cd /usr/lib/python3/dist-packages
$ sudo ln -s apt_pkg.cpython-38-x86_64-linux-gnu.so apt_pkg.so
$ sudo ln -s apt_inst.cpython-38-x86_64-linux-gnu.so apt_inst.so
```

### Пререквизиты - SSH доступ
Создание нод кластера и обеспечение SSH доступа производится аналогично 
[первой части задания](./14_25_kubernetes_prod.MD#создание-нод-для-кластера).  

### Получение Kubespray
```bash
$ sudo apt install -y git
$ git clone https://github.com/kubernetes-sigs/kubespray.git
```  

### Установка зависимостей
```bash
$ cd kubespray/
$ sudo pip install -r requirements.txt
$ ansible --version

ansible [core 2.15.8]
  config file = /home/ubuntu/kubespray/ansible.cfg
  configured module search path = ['/home/ubuntu/kubespray/library']
  ansible python module location = /usr/local/lib/python3.11/dist-packages/ansible
  ansible collection location = /home/ubuntu/.ansible/collections:/usr/share/ansible/collections
  executable location = /usr/local/bin/ansible
  python version = 3.11.7 (main, Dec  8 2023, 18:56:57) [GCC 9.4.0] (/usr/bin/python3)
  jinja version = 3.1.2
  libyaml = False
```  

### Создание инвентаря

```bash
cp -rfp inventory/sample inventory/kubernetes-prod
```  

Заполняем инвентарь с 
[таким](/kubernetes-prod/kubespray-inventory/inventory.ini) содержанием  

Проверяем и правим конфигурацию:  
**inventory/kubernetes-prod/group_vars/all/all.yml**  
**inventory/kubernetes-prod/group_vars/k8s_cluster/k8s-cluster.yml**  

Запускается сценарий командой:  
```bash
$ ansible-playbook \
  -i inventory/kubernetes-prod/inventory.ini \
  --become \
  --become-user=root \
  --user=ubuntu \
  --key-file=/home/ubuntu/.ssh/id_rsa cluster.yml
```  

После успешной отработки сценария остается сходить на master ноду за kubeconfig 
файлом, по пути **/etc/kubernetes/admin.conf**  

Проверить успешность установки:  
```bash
$ k get nodes
NAME       STATUS   ROLES           AGE     VERSION
master     Ready    control-plane   8m24s   v1.28.5
worker-1   Ready    <none>          7m29s   v1.28.5
worker-2   Ready    <none>          7m29s   v1.28.5
worker-3   Ready    <none>          7m28s   v1.28.5

$ k cluster-info 
Kubernetes control plane is running at https://kubernetes:6443

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```  

Для возможности обращаться к api серверу, его адрес в kubeconfig локального 
компьютера указываем не как ip, а как доменное имя kubernetes. В hosts файле 
локального компьютера нужно будет внести запись, которая разрешает kubernetes в 
публичный ip адрес api сервера.  

```bash
$ grep kubernetes /etc/hosts
< публичный IP master ноды > master kubernetes
```  

<br>  

## Задание со 🌟

Для выполнения задания со 🌟 немного изменится код развертывания инфраструктуры.  
Добавляется пара мастер нод, внешний балансировщик и джамп хост.   
Terraform код равертывания инфраструктуры описан в поддиректории 
[iac-advanced](/kubernetes-prod/iac-advanced/).   
Установку кластера буду производить уже при помощи 
[kubespray](https://github.com/kubernetes-sigs/kubespray).   
Публичный IP адрес будет только у джамп хоста bastion, поэтому запускать 
сценарии буду с него.  
Доступ к api серверам будет настраиваться через облачный L3/L4 балансировщик.  

### Настройка локальной машины

```bash
$ cat <<EOF | sudo tee -a /etc/hosts
< публичный IP хоста bastion > bastion
EOF

$ cat <<EOF >>~/.ssh/config
Host bastion
  Hostname < публичный IP хоста bastion >
  User ubuntu
  Port 22
EOF
```  

### Настройка хоста bastion

```bash
# на хосте bastion
$ cat <<EOF | sudo tee -a /etc/hosts
192.168.10.11 master-1
192.168.10.12 master-2
192.168.10.13 master-3
192.168.10.21 worker-1
192.168.10.22 worker-2
EOF

$ cat <<EOF >>~/.ssh/config
Host master-1
  Hostname 192.168.10.11
  User ubuntu
  Port 22
  IdentityFile /home/ubuntu/.ssh/id_rsa
Host master-2
  Hostname 192.168.10.12
  User ubuntu
  Port 22
  IdentityFile /home/ubuntu/.ssh/id_rsa
Host master-3
  Hostname 192.168.10.13
  User ubuntu
  Port 22
  IdentityFile /home/ubuntu/.ssh/id_rsa
Host worker-1
  Hostname 192.168.10.21
  User ubuntu
  Port 22
  IdentityFile /home/ubuntu/.ssh/id_rsa
Host worker-2
  Hostname 192.168.10.22
  User ubuntu
  Port 22
  IdentityFile /home/ubuntu/.ssh/id_rsa
EOF
```  

### Пререквизиты - python3 и pip

Удовлетворить требованиям requirements.txt мастер ветки проекта Kubespray, 
используя дистрибутив Ubuntu20.04, оказалось весьма нетривиальной задачей:  
```bash
$ sudo add-apt-repository ppa:deadsnakes/ppa
$ sudo apt-get update
$ sudo apt-get install python3.11 -y 
$ sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 2
$ sudo update-alternatives --config python3
# установка pip от рута:
$ sudo -i
# curl https://bootstrap.pypa.io/get-pip.py | python3
# exit

$ python3 -V
Python 3.11.7

$ pip -V
pip 23.3.2 from /home/ubuntu/.local/lib/python3.11/site-packages/pip (python 3.11)

# плюс еще немного "приседаний" в связи с отсутствующим apt_pkg:
$ cd /usr/lib/python3/dist-packages
$ sudo ln -s apt_pkg.cpython-38-x86_64-linux-gnu.so apt_pkg.so
$ sudo ln -s apt_inst.cpython-38-x86_64-linux-gnu.so apt_inst.so
```   

### Получение Kubespray
```bash
$ sudo apt install -y git
$ git clone https://github.com/kubernetes-sigs/kubespray.git
```  

### Установка зависимостей
```bash
$ cd kubespray/
$ sudo pip install -r requirements.txt
$ ansible --version

ansible [core 2.15.8]
  config file = /home/ubuntu/kubespray/ansible.cfg
  configured module search path = ['/home/ubuntu/kubespray/library']
  ansible python module location = /usr/local/lib/python3.11/dist-packages/ansible
  ansible collection location = /home/ubuntu/.ansible/collections:/usr/share/ansible/collections
  executable location = /usr/local/bin/ansible
  python version = 3.11.7 (main, Dec  8 2023, 18:56:57) [GCC 9.4.0] (/usr/bin/python3)
  jinja version = 3.1.2
  libyaml = False
```  

### Создание инвентаря

```bash
cp -rfp inventory/sample inventory/kubernetes-prod
```  

### Генерируем hosts.yml

```bash
$ declare -a IPS=(192.168.10.11 192.168.10.12 192.168.10.13 192.168.10.21 192.168.10.22)
$ CONFIG_FILE=inventory/kubernetes-prod/hosts.yml python3 contrib/inventory_builder/inventory.py ${IPS[@]}
```  
и проверяем inventory/kubernetes-prod/hosts.yml  

### Запуск сценария

```bash
$ ansible-playbook \
  -i inventory/kubernetes-prod/hosts.yml \
  --become \
  --become-user=root \
  --user=ubuntu \
  --key-file=/home/ubuntu/.ssh/id_rsa cluster.yml
```  

### Проверка успешности установки  
  
С мастер ноды:  
```bash
$ sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get nodes -o wide
NAME    STATUS   ROLES           AGE     VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
node1   Ready    control-plane   6m6s    v1.28.5   192.168.10.11   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.7.11
node2   Ready    control-plane   5m45s   v1.28.5   192.168.10.12   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.7.11
node3   Ready    control-plane   5m39s   v1.28.5   192.168.10.13   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.7.11
node4   Ready    <none>          4m43s   v1.28.5   192.168.10.21   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.7.11
node5   Ready    <none>          4m43s   v1.28.5   192.168.10.22   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.7.11
```  

Настроив kubeconfig и hosts на локальной машине:  
```bash
$ grep kubernetes /etc/hosts
178.154.206.101 kubernetes

$ k cluster-info 
Kubernetes control plane is running at https://kubernetes:6443
To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

$ k get nodes -o wide
NAME    STATUS   ROLES           AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
node1   Ready    control-plane   13m   v1.28.5   192.168.10.11   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.7.11
node2   Ready    control-plane   13m   v1.28.5   192.168.10.12   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.7.11
node3   Ready    control-plane   13m   v1.28.5   192.168.10.13   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.7.11
node4   Ready    <none>          12m   v1.28.5   192.168.10.21   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.7.11
node5   Ready    <none>          12m   v1.28.5   192.168.10.22   <none>        Ubuntu 20.04.6 LTS   5.4.0-169-generic   containerd://1.7.11
```  

Получили кластер на полностью приватных адресах, тем не менее с доступным в 
интернете api сервером.   

### TODO
Разобраться с конфигурационными файлами kubespray для более корректной 
организации доступа в кластер.  
