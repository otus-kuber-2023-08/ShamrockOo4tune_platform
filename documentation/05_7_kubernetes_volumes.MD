# Volumes, Storages, StatefulSetStatefulSet  

## Часть 1. Установка и запуск Kind  

1. Установил [statefulset](/kubernetes-volumes/minio-statefulset.yaml) и [service](/kubernetes-volumes/minio-headless-service.yaml) согласно методических указаний.  
2. Установил консольный клиент **mc** по [иснтрукции](https://min.io/docs/minio/linux/reference/minio-mc.html).  
---  
<br>  

## Часть 2. Задание со ⭐ 

1. Закодировал строки с "секретными значениями":  
    ```bash
    $ echo -n 'minio' | base64
    bWluaW8=
    
    $ echo -n 'minio123' | base64
    bWluaW8xMjM=
    ```  
2. Создал манифест для определения секретов:  
    ```bash
    $ k create secret generic minio-keys \
      --from-literal=access_key='bWluaW8=' \
      --from-literal=secret_key='bWluaW8xMjM=' \
      --dry-run=server \
      -o yaml > minio-secrets.yaml 
    ```
3. Отредактировал [minio-secrets.yaml](/kubernetes-volumes/minio-secrets.yaml) и применил его.   

4. Обновил [манифест minio-statefulset.yaml](/kubernetes-volumes/minio-statefulset.yaml) для проброса переменных из секретов.  

5. Проверил наличие переменных внутри **pod**:  
    ```bash
    $ k get pods
    NAME      READY   STATUS    RESTARTS   AGE
    minio-0   1/1     Running   0          4m8s
    
    $ k exec -it minio-0 -- sh -c 'env | grep minio'
    HOSTNAME=minio-0
    MINIO_ACCESS_KEY=minio
    MINIO_SECRET_KEY=minio123
    ```  
---
<br>  

## Часть 3. Создание и использование PersistentVolumeClaim Kubernetes(опционально)  

Создал [манифест для pv](../kubernetes-volumes/my-pv.yaml) с описанием pv **my-pv**  
Создал [манифест для pvc](../kubernetes-volumes/my-pvc.yaml) с описанием pvc **my-pvc**  
Применил манифест и проверил состояние - **Bound**  
```bash
$ k get pvc
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-minio-0   Bound    pvc-e040428a-e3cd-4d13-a464-da4c127557e5   10Gi       RWO            standard       45m
my-pvc         Bound    my-pv                                      1Gi        RWO            standart       19s
```
Создал [манифест для pod](../kubernetes-volumes/my-pod.yaml) с описанием pod **my-pod**  
Создал по примонтированному пути файл **data.txt** и проверил что он сохраняется если перевоссоздать под.  
 