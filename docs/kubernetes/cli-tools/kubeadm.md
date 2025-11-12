# kubeadm - Управление кластером

Справочник команд kubeadm для создания, управления и обслуживания Kubernetes кластера.

## Предварительные требования

- kubeadm версии 1.28+
- Container runtime (containerd, CRI-O, Docker)
- Необходимые порты открыты
- Swap отключен

---

## Инициализация кластера

### kubeadm init

**Базовая инициализация:**

```bash
kubeadm init
```

**С параметрами:**

```bash
kubeadm init --pod-network-cidr=<CIDR> --apiserver-advertise-address=<IP>
kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.1.100
```

| Флаг | Описание |
|------|----------|
| `--pod-network-cidr` | CIDR для pod network (required для CNI) |
| `--apiserver-advertise-address` | IP для API server |
| `--apiserver-bind-port` | Порт API server (default 6443) |
| `--service-cidr` | CIDR для services (default 10.96.0.0/12) |
| `--service-dns-domain` | DNS domain для services (default cluster.local) |
| `--control-plane-endpoint` | Endpoint для HA кластера |
| `--upload-certs` | Загрузка сертификатов в кластер |
| `--certificate-key` | Ключ для шифрования сертификатов |
| `--kubernetes-version` | Версия Kubernetes |
| `--image-repository` | Registry для container images |
| `--dry-run` | Тестовый запуск |
| `--ignore-preflight-errors` | Пропустить preflight проверки |
| `--skip-phases` | Пропустить определенные фазы |

**High Availability кластер:**

```bash
kubeadm init --control-plane-endpoint=<LOAD_BALANCER_DNS>:6443 --upload-certs --pod-network-cidr=10.244.0.0/16
```

**Указание container runtime:**

```bash
kubeadm init --cri-socket=unix:///var/run/containerd/containerd.sock
kubeadm init --cri-socket=unix:///var/run/crio/crio.sock
```

**Custom image repository:**

```bash
kubeadm init --image-repository=registry.example.com/k8s
```

**Конкретная версия Kubernetes:**

```bash
kubeadm init --kubernetes-version=v1.28.0
```

### Init configuration file

**Генерация default конфигурации:**

```bash
kubeadm config print init-defaults > kubeadm-config.yaml
```

**Init с конфигурационным файлом:**

```bash
kubeadm init --config=kubeadm-config.yaml
```

**Пример конфигурации:**

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 192.168.1.100
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  kubeletExtraArgs:
    node-ip: 192.168.1.100
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.28.0
controlPlaneEndpoint: "k8s-lb.example.com:6443"
networking:
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
  dnsDomain: cluster.local
apiServer:
  certSANs:
  - "k8s-lb.example.com"
  - "192.168.1.100"
  extraArgs:
    authorization-mode: "Node,RBAC"
controllerManager:
  extraArgs:
    node-cidr-mask-size: "24"
scheduler: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.k8s.io
```

### Фазы инициализации

**Список фаз:**

```bash
kubeadm init phase
```

Фазы: preflight, certs, kubeconfig, kubelet-start, control-plane, etcd, upload-config, upload-certs, mark-control-plane, bootstrap-token, kubelet-finalize, addon.

**Запуск конкретной фазы:**

```bash
kubeadm init phase certs all
kubeadm init phase kubeconfig all
kubeadm init phase etcd local
```

**Пропуск фазы:**

```bash
kubeadm init --skip-phases=addon/kube-proxy
```

### Post-init setup

**Копирование kubeconfig:**

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

**Join command для workers:**

```bash
kubeadm token create --print-join-command
```

---

## Присоединение нод

### kubeadm join

**Join worker node:**

```bash
kubeadm join <CONTROL_PLANE_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>
```

**Join control plane node:**

```bash
kubeadm join <CONTROL_PLANE_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH> --control-plane --certificate-key <KEY>
```

| Флаг | Описание |
|------|----------|
| `--token` | Bootstrap token |
| `--discovery-token-ca-cert-hash` | CA cert hash для валидации |
| `--discovery-token-unsafe-skip-ca-verification` | Пропустить CA verification (не рекомендуется) |
| `--control-plane` | Join как control plane node |
| `--certificate-key` | Ключ для расшифровки сертификатов |
| `--apiserver-advertise-address` | IP для API server на новой control plane node |
| `--cri-socket` | Container runtime socket |
| `--node-name` | Имя node |
| `--ignore-preflight-errors` | Пропустить preflight проверки |

**Join с конфигурационным файлом:**

```bash
kubeadm join --config=join-config.yaml
```

**Join configuration:**

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: "192.168.1.100:6443"
    token: "abcdef.0123456789abcdef"
    caCertHashes:
    - "sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  kubeletExtraArgs:
    node-ip: 192.168.1.101
```

**Join control plane configuration:**

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: "k8s-lb.example.com:6443"
    token: "abcdef.0123456789abcdef"
    caCertHashes:
    - "sha256:1234567890abcdef"
controlPlane:
  localAPIEndpoint:
    advertiseAddress: 192.168.1.102
    bindPort: 6443
  certificateKey: "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
```

---

## Token управление

### Создание token

```bash
kubeadm token create
kubeadm token create --ttl 24h
kubeadm token create --ttl 0
```

Флаг `--ttl 0` создает token без expiration.

**С print join command:**

```bash
kubeadm token create --print-join-command
```

**Указание token value:**

```bash
kubeadm token create <TOKEN_VALUE>
```

Token format: `[a-z0-9]{6}.[a-z0-9]{16}`

**С описанием:**

```bash
kubeadm token create --description="Token for new workers"
```

**С groups:**

```bash
kubeadm token create --groups=system:bootstrappers:kubeadm:default-node-token
```

### Просмотр tokens

```bash
kubeadm token list
```

Вывод: token, ttl, expires, usages, description, extra groups.

### Удаление token

```bash
kubeadm token delete <TOKEN>
kubeadm token delete abcdef.0123456789abcdef
```

---

## Сертификаты

### Просмотр сертификатов

**Проверка expiration:**

```bash
kubeadm certs check-expiration
```

Вывод показывает все сертификаты и их expiration dates.

**Список сертификатов:**

- admin.conf
- apiserver
- apiserver-etcd-client
- apiserver-kubelet-client
- controller-manager.conf
- etcd-healthcheck-client
- etcd-peer
- etcd-server
- front-proxy-client
- scheduler.conf

### Обновление сертификатов

**Обновление всех сертификатов:**

```bash
kubeadm certs renew all
```

**Обновление конкретного сертификата:**

```bash
kubeadm certs renew apiserver
kubeadm certs renew admin.conf
kubeadm certs renew controller-manager.conf
```

**Доступные сертификаты для renew:**

- admin.conf
- apiserver
- apiserver-etcd-client
- apiserver-kubelet-client
- controller-manager.conf
- etcd-healthcheck-client
- etcd-peer
- etcd-server
- front-proxy-client
- scheduler.conf

### Генерация сертификатов

```bash
kubeadm init phase certs all
kubeadm init phase certs apiserver
kubeadm init phase certs etcd-server
```

### Certificate Key

**Генерация certificate key:**

```bash
kubeadm init phase upload-certs --upload-certs
```

Certificate key используется для join control plane nodes.

**Certificate key TTL:**

Certificate key expires через 2 часа после создания.

---

## Конфигурация

### Печать конфигурации

**Init defaults:**

```bash
kubeadm config print init-defaults
kubeadm config print init-defaults --component-configs KubeletConfiguration
```

**Join defaults:**

```bash
kubeadm config print join-defaults
```

### Миграция конфигурации

```bash
kubeadm config migrate --old-config old-config.yaml --new-config new-config.yaml
```

Миграция конфигурации между API versions.

### Просмотр текущей конфигурации

```bash
kubectl get configmap -n kube-system kubeadm-config -o yaml
```

### Images управление

**Список требуемых images:**

```bash
kubeadm config images list
kubeadm config images list --kubernetes-version v1.28.0
```

**Pull images:**

```bash
kubeadm config images pull
kubeadm config images pull --cri-socket=unix:///var/run/containerd/containerd.sock
```

**Custom image repository:**

```bash
kubeadm config images list --image-repository=registry.example.com/k8s
kubeadm config images pull --image-repository=registry.example.com/k8s
```

---

## Обновление кластера

### Планирование обновления

```bash
kubeadm upgrade plan
kubeadm upgrade plan --kubernetes-version v1.28.0
```

Вывод показывает:
- Текущую версию
- Доступные версии для обновления
- Необходимые шаги
- Компоненты для обновления

### Применение обновления

**На первой control plane node:**

```bash
kubeadm upgrade apply v1.28.0
kubeadm upgrade apply v1.28.0 --yes
```

| Флаг | Описание |
|------|----------|
| `--yes` | Автоматическое подтверждение |
| `--force` | Принудительное обновление |
| `--dry-run` | Тестовый запуск |
| `--etcd-upgrade` | Обновление etcd (default true) |
| `--certificate-renewal` | Обновление сертификатов (default true) |
| `--patches` | Директория с patches |
| `--print-config` | Печать конфигурации |

**На дополнительных control plane nodes:**

```bash
kubeadm upgrade node
```

**На worker nodes:**

```bash
kubeadm upgrade node
```

### Diff обновления

```bash
kubeadm upgrade diff v1.28.0
```

Показывает изменения в manifests перед обновлением.

### Обновление kubelet config

```bash
kubeadm upgrade node phase kubelet-config
```

---

## Reset кластера

### Полный reset

```bash
kubeadm reset
kubeadm reset --force
```

| Флаг | Описание |
|------|----------|
| `--force` | Reset без подтверждения |
| `--cleanup-tmp-dir` | Очистка /etc/kubernetes/tmp |
| `--cri-socket` | Container runtime socket |
| `--ignore-preflight-errors` | Пропустить preflight проверки |

**Post-reset cleanup:**

```bash
rm -rf /etc/cni/net.d
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
ipvsadm --clear
```

### Фазы reset

```bash
kubeadm reset phase
```

Фазы: preflight, remove-etcd-member, cleanup-node.

**Запуск конкретной фазы:**

```bash
kubeadm reset phase cleanup-node
```

---

## Alpha функции

### Alpha команды

```bash
kubeadm alpha
```

Experimental функции для тестирования.

---

## Kubeconfig генерация

### Admin kubeconfig

```bash
kubeadm init phase kubeconfig admin
```

Создает `/etc/kubernetes/admin.conf`.

**Все kubeconfigs:**

```bash
kubeadm init phase kubeconfig all
```

Создает:
- admin.conf
- kubelet.conf
- controller-manager.conf
- scheduler.conf

**User kubeconfig:**

```bash
kubeadm kubeconfig user --client-name=<USER> --org=<ORG>
```

---

## Bootstrap tokens

### Bootstrap token format

```
[a-z0-9]{6}.[a-z0-9]{16}
```

Пример: `abcdef.0123456789abcdef`

### Token secrets

Bootstrap tokens хранятся как secrets в namespace `kube-system`:

```bash
kubectl get secrets -n kube-system | grep bootstrap-token
```

**Secret naming:**

```
bootstrap-token-<TOKEN_ID>
```

Где TOKEN_ID - первые 6 символов token.

---

## Preflight проверки

### Запуск preflight checks

```bash
kubeadm init phase preflight
kubeadm join phase preflight
```

**Проверяемые условия:**

- Container runtime running
- Swap отключен
- Required ports доступны
- Kubernetes version compatibility
- Hostname resolution
- Network plugin requirements
- System resources

### Пропуск проверок

```bash
kubeadm init --ignore-preflight-errors=all
kubeadm init --ignore-preflight-errors=Swap,NumCPU
```

**Часто пропускаемые:**

- Swap - если swap включен
- NumCPU - если менее 2 CPU
- Mem - если менее 1700MB RAM
- FileContent - для конкретных файлов
- Port-<PORT> - для конкретных портов

---

## Addons

### CoreDNS

**Установка через kubeadm:**

```bash
kubeadm init phase addon coredns
```

**Обновление CoreDNS:**

```bash
kubectl apply -f https://raw.githubusercontent.com/coredns/deployment/master/kubernetes/coredns.yaml.sed
```

### Kube-proxy

**Установка через kubeadm:**

```bash
kubeadm init phase addon kube-proxy
```

**Пропуск kube-proxy:**

```bash
kubeadm init --skip-phases=addon/kube-proxy
```

Используется при установке альтернативных CNI (Cilium в kube-proxy replacement mode).

---

## Высокая доступность

### HA топологии

**Stacked etcd:**

etcd на control plane nodes.

```bash
kubeadm init --control-plane-endpoint=<LB_DNS>:6443 --upload-certs
```

**External etcd:**

Отдельные etcd nodes.

```yaml
etcd:
  external:
    endpoints:
    - https://etcd1.example.com:2379
    - https://etcd2.example.com:2379
    - https://etcd3.example.com:2379
    caFile: /etc/kubernetes/pki/etcd/ca.crt
    certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
    keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key
```

### Load Balancer requirements

**Для control plane endpoint:**

- Port 6443 (API server)
- TCP load balancing
- Health checks на /healthz

---

## Troubleshooting

### Init проблемы

**Проверка container runtime:**

```bash
systemctl status containerd
systemctl status crio
```

**Проверка портов:**

```bash
netstat -tuln | grep -E '6443|2379|2380|10250|10251|10252'
```

**Логи kubelet:**

```bash
journalctl -u kubelet -f
```

**Проверка swap:**

```bash
free -h
swapoff -a
```

### Join проблемы

**Проверка token:**

```bash
kubeadm token list
```

Token может быть expired - создать новый:

```bash
kubeadm token create --print-join-command
```

**Проверка CA cert hash:**

```bash
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
```

**Проверка connectivity к API server:**

```bash
telnet <CONTROL_PLANE_IP> 6443
curl -k https://<CONTROL_PLANE_IP>:6443/healthz
```

### Certificate проблемы

**Проверка expiration:**

```bash
kubeadm certs check-expiration
```

**Manual проверка сертификата:**

```bash
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout
```

**Обновление expired сертификатов:**

```bash
kubeadm certs renew all
systemctl restart kubelet
```

### Upgrade проблемы

**Проверка версии:**

```bash
kubeadm version
kubelet --version
kubectl version
```

**Откат после failed upgrade:**

Restore etcd backup и переустановить старую версию компонентов.

### Reset проблемы

**Ручная очистка:**

```bash
rm -rf /etc/kubernetes/
rm -rf /var/lib/kubelet/
rm -rf /var/lib/etcd/
rm -rf $HOME/.kube/
```

**Очистка CNI:**

```bash
rm -rf /etc/cni/net.d/
rm -rf /opt/cni/bin/
```

**Очистка iptables:**

```bash
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
```

---

## Best Practices

**Backup перед обновлением:**

```bash
cp -r /etc/kubernetes /etc/kubernetes.backup
ETCDCTL_API=3 etcdctl snapshot save snapshot.db
```

**Документирование token и certificate keys:**

Сохранить output kubeadm init для будущих join операций.

**Регулярное обновление сертификатов:**

Настроить автоматическое обновление через cronjob или systemd timer.

**Мониторинг expiration:**

```bash
kubeadm certs check-expiration
```

Проверять регулярно (monthly).

**Тестирование обновлений:**

Тестировать на staging кластере перед production.

**HA setup для production:**

Минимум 3 control plane nodes, external load balancer.