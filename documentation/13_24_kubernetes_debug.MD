# Отладка и тестирование в Kubernetes  

## Подготовка Kubernetes кластера  

Кластер разворачивается при помощи подхода IAC (terraform и gitlab-ci) из [репозитория](https://gitlab.com/shamrockoo4tune/iac-for-kubernetes-gitops)
по [инструкции](https://gitlab.com/shamrockoo4tune/iac-for-kubernetes-gitops/-/blob/master/instructions.md?ref_type=heads)    

<br>  

## kubectl-debug

оригинальный проект https://github.com/aylei/kubectl-debug
более свежий форк https://github.com/JamesTGrant/kubectl-debug

Более не поддерживается и не развивается и не работает с последними версиями k8s
Предлагается использовать [ephemeral containers](https://kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/)  

Запускаем контейнер с вебсервером.
Запускаем эфемерный контейнер и устанавливаем в него starce  

## ephemeral containers

Отладка вебсервера  
```bash
$ k run nginx --image=nginx
pod/nginx created

$ k debug -it nginx --image=alpine --target=nginx
Targeting container "nginx". If you don't see processes from this container it may be because the container runtime doesn't support this feature.
Defaulting debug container name to debugger-ct6vm.
If you don't see a command prompt, try pressing enter.

/ # apk add strace
...
OK: 10 MiB in 22 packages
/ # strace ls
execve("/bin/ls", ["ls"], 0x7fff429ac410 /* 14 vars */) = 0
arch_prctl(ARCH_SET_FS, 0x7fe693066b08) = 0
set_tid_address(0x7fe693066f70)         = 53
brk(NULL)                               = 0x556aa9c36000
brk(0x556aa9c38000)                     = 0x556aa9c38000
mmap(0x556aa9c36000, 4096, PROT_NONE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0x556aa9c36000
mprotect(0x7fe693063000, 4096, PROT_READ) = 0
mprotect(0x556aa7fd6000, 16384, PROT_READ) = 0
getuid()                                = 0
ioctl(0, TIOCGWINSZ, {ws_row=17, ws_col=234, ws_xpixel=0, ws_ypixel=0}) = 0
ioctl(1, TIOCGWINSZ, {ws_row=17, ws_col=234, ws_xpixel=0, ws_ypixel=0}) = 0
ioctl(1, TIOCGWINSZ, {ws_row=17, ws_col=234, ws_xpixel=0, ws_ypixel=0}) = 0
stat(".", {st_mode=S_IFDIR|0755, st_size=4096, ...}) = 0
open(".", O_RDONLY|O_LARGEFILE|O_CLOEXEC|O_DIRECTORY) = 3
fcntl(3, F_SETFD, FD_CLOEXEC)           = 0
mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7fe692fc3000
getdents64(3, 0x7fe692fc3038 /* 19 entries */, 2048) = 464
lstat("./home", {st_mode=S_IFDIR|0755, st_size=4096, ...}) = 0
lstat("./bin", {st_mode=S_IFDIR|0755, st_size=4096, ...}) = 0
lstat("./mnt", {st_mode=S_IFDIR|0755, st_size=4096, ...}) = 0
lstat("./run", {st_mode=S_IFDIR|0755, st_size=4096, ...}) = 0
lstat("./proc", {st_mode=S_IFDIR|0555, st_size=0, ...}) = 0
lstat("./dev", {st_mode=S_IFDIR|0755, st_size=380, ...}) = 0
lstat("./usr", {st_mode=S_IFDIR|0755, st_size=4096, ...}) = 0
lstat("./root", {st_mode=S_IFDIR|0700, st_size=4096, ...}) = 0
lstat("./sys", {st_mode=S_IFDIR|0555, st_size=0, ...}) = 0
lstat("./sbin", {st_mode=S_IFDIR|0755, st_size=4096, ...}) = 0
lstat("./tmp", {st_mode=S_IFDIR|S_ISVTX|0777, st_size=4096, ...}) = 0
lstat("./srv", {st_mode=S_IFDIR|0755, st_size=4096, ...}) = 0
lstat("./etc", {st_mode=S_IFDIR|0755, st_size=4096, ...}) = 0
lstat("./media", {st_mode=S_IFDIR|0755, st_size=4096, ...}) = 0
lstat("./lib", {st_mode=S_IFDIR|0755, st_size=4096, ...}) = 0
lstat("./var", {st_mode=S_IFDIR|0755, st_size=4096, ...}) = 0
lstat("./opt", {st_mode=S_IFDIR|0755, st_size=4096, ...}) = 0
getdents64(3, 0x7fe692fc3038 /* 0 entries */, 2048) = 0
close(3)                                = 0
munmap(0x7fe692fc3000, 8192)            = 0
ioctl(1, TIOCGWINSZ, {ws_row=17, ws_col=234, ws_xpixel=0, ws_ypixel=0}) = 0
writev(1, [{iov_base="\33[1;34mbin\33[m    \33[1;34mdev\33[m  "..., iov_len=285}, {iov_base="\n", iov_len=1}], 2bin    dev    etc    home   lib    media  mnt    opt    proc   root   run    sbin   srv    sys    tmp    usr    var
) = 286
exit_group(0)                           = ?
+++ exited with 0 +++
```  

## iptables-tailer

Что тут делать нужно совершенно не понятно. Оператор сразу валится с goшными ошибками  

git clone git@github.com:box/kube-iptables-tailer.git
cd kube-iptables-tailer
docker build -f Dockerfile -t kube-iptables-tailer:v0.1.0 .

Применение ресурсов для деплоя netperf-operator из https://github.com/piontec/netperf-operator/tree/master/deploy согласно методичке
kubectl apply -f ./kit/crd.yaml
kubectl apply -f ./kit/rbac.yaml
kubectl apply -f ./kit/operator.yaml

Netperf ресурс
k apply -f kubernetes-debug/kit/cr.yaml
netperf.app.example.com/example created

kubectl describe netperf.app.example.com/example
Name:         example
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  app.example.com/v1alpha1
Kind:         Netperf
Metadata:
  Creation Timestamp:  2023-10-29T08:48:43Z
  Generation:          1
  Resource Version:    1201990
  UID:                 e2732a47-7fd7-4e92-9958-50f47265e1ca
Events:                <none>


