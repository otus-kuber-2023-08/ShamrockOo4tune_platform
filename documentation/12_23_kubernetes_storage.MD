# CSI. Обзор подсистем хранения данных в Kubernetes  

## Подготовка Kubernetes кластера  

Кластер разворачивается при помощи подхода IAC (terraform и gitlab-ci) из [репозитория](https://gitlab.com/shamrockoo4tune/iac-for-kubernetes-gitops)
по [инструкции](https://gitlab.com/shamrockoo4tune/iac-for-kubernetes-gitops/-/blob/master/instructions.md?ref_type=heads)    

<br>  

## StorageClass для CSI Host Path Driver

Установка драйвера произведена по инструкции из [проекта](https://github.com/kubernetes-csi/csi-driver-host-path/blob/master/docs/deploy-1.17-and-later.md)  
  
```bash
$ git clone https://github.com/kubernetes-csi/csi-driver-host-path.git
$ cd csi-driver-host-path/
$ deploy/kubernetes-latest/deploy.sh
```  

Проверка  
```bash
$ kubectl get pods
NAME                   READY   STATUS    RESTARTS   AGE
csi-hostpath-socat-0   1/1     Running   0          3m41s
csi-hostpathplugin-0   8/8     Running   0          3m45s
```

### StorageClass

Из директории с текущим проектом:
```bash
$ k apply -f ./kubernetes-storage/storageclass.yaml 
storageclass.storage.k8s.io/csi-hostpath-sc created

$ k get storageclasses.storage.k8s.io 
NAME                           PROVISIONER                     RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
csi-hostpath-sc                hostpath.csi.k8s.io             Delete          Immediate              true                   7s
yc-network-hdd (default)       disk-csi-driver.mks.ycloud.io   Delete          WaitForFirstConsumer   true                   51m
yc-network-nvme                disk-csi-driver.mks.ycloud.io   Delete          WaitForFirstConsumer   true                   51m
yc-network-ssd                 disk-csi-driver.mks.ycloud.io   Delete          WaitForFirstConsumer   true                   51m
yc-network-ssd-io-m3           disk-csi-driver.mks.ycloud.io   Delete          WaitForFirstConsumer   true                   51m
yc-network-ssd-nonreplicated   disk-csi-driver.mks.ycloud.io   Delete          WaitForFirstConsumer   true                   51m
```  

### PVC

```bash
$ k apply -f ./kubernetes-storage/pvc.yaml
persistentvolumeclaim/storage-pvc created

$ k get pvc
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
csi-pvc   Bound    pvc-7f69f08b-4c3c-4b79-a0b4-9dfe51029973   1Gi        RWO            csi-hostpath-sc   2m35s
```  

### Pod

```bash
$ k apply -f ./kubernetes-storage/pod.yaml 
pod/storage-pod created
```  
