# kubectl - Хранилище

Справочник команд для управления PersistentVolume, PersistentVolumeClaim, StorageClass и Volume.

## Предварительные требования

- kubectl версии 1.28+
- Доступ к Kubernetes кластеру
- Понимание концепций persistent storage

---

## PersistentVolume операции

### Просмотр PersistentVolume

```bash
kubectl get persistentvolumes
kubectl get pv
kubectl get pv <n>
kubectl describe pv <n>
```

**С дополнительной информацией:**

```bash
kubectl get pv -o wide
kubectl get pv --sort-by=.spec.capacity.storage
```

**Статус PV:**

```bash
kubectl get pv <n> -o jsonpath='{.status.phase}'
```

| Phase | Описание |
|-------|----------|
| Available | PV свободен и доступен для bind |
| Bound | PV привязан к PVC |
| Released | PVC удален, но PV не reclaimed |
| Failed | Автоматический reclaim failed |

### PersistentVolume манифест

**Базовый PV:**

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-data
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/data
```

**Access Modes:**

| Mode | Сокращение | Описание |
|------|------------|----------|
| ReadWriteOnce | RWO | Чтение-запись одной node |
| ReadOnlyMany | ROX | Чтение только множеством nodes |
| ReadWriteMany | RWX | Чтение-запись множеством nodes |
| ReadWriteOncePod | RWOP | Чтение-запись одним pod (1.22+) |

**Reclaim Policy:**

| Policy | Поведение |
|--------|-----------|
| Retain | PV сохраняется после удаления PVC |
| Delete | PV удаляется после удаления PVC |
| Recycle | Очистка данных для повторного использования (deprecated) |

**NFS PV:**

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-nfs
spec:
  capacity:
    storage: 50Gi
  accessModes:
  - ReadWriteMany
  nfs:
    server: <NFS_SERVER_IP>
    path: /exports/data
  storageClassName: nfs
  persistentVolumeReclaimPolicy: Retain
```

**iSCSI PV:**

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-iscsi
spec:
  capacity:
    storage: 100Gi
  accessModes:
  - ReadWriteOnce
  iscsi:
    targetPortal: <ISCSI_TARGET_IP>:3260
    iqn: iqn.2001-04.com.example:storage.disk1
    lun: 0
    fsType: ext4
    readOnly: false
```

**Local PV:**

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-local
spec:
  capacity:
    storage: 100Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /mnt/disks/ssd1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - <NODE_NAME>
```

Local PV требует nodeAffinity для привязки к specific node.

### Создание PV

```bash
kubectl apply -f persistentvolume.yaml
```

PersistentVolume обычно создается администратором кластера.

### Редактирование PV

```bash
kubectl edit pv <n>
kubectl patch pv <n> -p '{"spec":{"persistentVolumeReclaimPolicy":"Delete"}}'
```

**Изменение reclaim policy:**

```bash
kubectl patch pv <n> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
```

### Удаление PV

```bash
kubectl delete pv <n>
```

PV с Bound статусом нельзя удалить без force.

**Принудительное удаление:**

```bash
kubectl delete pv <n> --force --grace-period=0
```

### Освобождение PV после Released

```bash
kubectl patch pv <n> -p '{"spec":{"claimRef":null}}'
```

Удаление claimRef переводит PV обратно в Available.

---

## PersistentVolumeClaim операции

### Создание PVC

**Императивное создание:**

```bash
kubectl create -f pvc.yaml
```

**PVC манифест:**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-data
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: standard
```

**Без указания StorageClass:**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-manual
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: ""
```

PVC будет bind к существующему PV с matching параметрами.

**С selector:**

```yaml
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  selector:
    matchLabels:
      type: fast
```

Selector для выбора конкретного PV по labels.

### Просмотр PVC

```bash
kubectl get persistentvolumeclaims
kubectl get pvc
kubectl get pvc <n>
kubectl describe pvc <n>
```

**С дополнительной информацией:**

```bash
kubectl get pvc -o wide
kubectl get pvc --all-namespaces
```

**Статус PVC:**

```bash
kubectl get pvc <n> -o jsonpath='{.status.phase}'
```

| Phase | Описание |
|-------|----------|
| Pending | PVC ожидает bind к PV |
| Bound | PVC привязан к PV |
| Lost | PV утрачен (node failure) |

**PV для PVC:**

```bash
kubectl get pvc <n> -o jsonpath='{.spec.volumeName}'
```

**Размер хранилища:**

```bash
kubectl get pvc <n> -o jsonpath='{.status.capacity.storage}'
```

### Изменение PVC

**Расширение размера PVC:**

```bash
kubectl edit pvc <n>
```

Изменить `spec.resources.requests.storage` на больший размер.

```bash
kubectl patch pvc <n> -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

Требует StorageClass с `allowVolumeExpansion: true`.

**Проверка allowVolumeExpansion:**

```bash
kubectl get storageclass <STORAGECLASS_NAME> -o jsonpath='{.allowVolumeExpansion}'
```

### Удаление PVC

```bash
kubectl delete pvc <n>
kubectl delete pvc --all
```

При удалении PVC, поведение PV зависит от reclaim policy.

### Использование PVC в Pod

**Volume из PVC:**

```yaml
spec:
  containers:
  - name: app
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: pvc-data
```

**ReadOnly mount:**

```yaml
volumeMounts:
- name: data
  mountPath: /data
  readOnly: true
```

---

## StorageClass операции

### Просмотр StorageClass

```bash
kubectl get storageclasses
kubectl get sc
kubectl get sc <n>
kubectl describe sc <n>
```

**Default StorageClass:**

```bash
kubectl get sc -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'
```

### StorageClass манифест

**Базовый StorageClass:**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

**Provisioners:**

| Provisioner | Использование |
|-------------|---------------|
| kubernetes.io/aws-ebs | AWS EBS volumes |
| kubernetes.io/gce-pd | GCE persistent disks |
| kubernetes.io/azure-disk | Azure disk |
| kubernetes.io/cinder | OpenStack Cinder |
| kubernetes.io/vsphere-volume | vSphere VMDK |
| kubernetes.io/no-provisioner | Static provisioning |

**Volume Binding Modes:**

| Mode | Поведение |
|------|-----------|
| Immediate | Немедленное создание PV при создании PVC |
| WaitForFirstConsumer | Отложенное создание до scheduling pod |

WaitForFirstConsumer рекомендуется для topology-aware provisioning.

**AWS EBS StorageClass:**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  fsType: ext4
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

**GCE PD StorageClass:**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: pd-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

**Azure Disk StorageClass:**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-disk
provisioner: disk.csi.azure.com
parameters:
  storageaccounttype: Premium_LRS
  kind: Managed
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

**NFS StorageClass (с external provisioner):**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs
provisioner: nfs.csi.k8s.io
parameters:
  server: <NFS_SERVER_IP>
  share: /exports
volumeBindingMode: Immediate
reclaimPolicy: Retain
```

### Создание StorageClass

```bash
kubectl apply -f storageclass.yaml
```

### Установка default StorageClass

```bash
kubectl patch storageclass <n> -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

**Снятие default:**

```bash
kubectl patch storageclass <n> -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

### Удаление StorageClass

```bash
kubectl delete storageclass <n>
kubectl delete sc <n>
```

---

## Volume types

### EmptyDir

```yaml
volumes:
- name: cache
  emptyDir: {}
```

Временное хранилище, удаляется при удалении pod.

**С memory backing:**

```yaml
volumes:
- name: cache
  emptyDir:
    medium: Memory
    sizeLimit: 128Mi
```

### HostPath

```yaml
volumes:
- name: data
  hostPath:
    path: /mnt/data
    type: DirectoryOrCreate
```

| Type | Поведение |
|------|-----------|
| DirectoryOrCreate | Создание директории если не существует |
| Directory | Директория должна существовать |
| FileOrCreate | Создание файла если не существует |
| File | Файл должен существовать |
| Socket | Unix socket должен существовать |
| CharDevice | Character device должен существовать |
| BlockDevice | Block device должен существовать |

### ConfigMap Volume

```yaml
volumes:
- name: config
  configMap:
    name: app-config
    items:
    - key: config.yaml
      path: config.yaml
```

### Secret Volume

```yaml
volumes:
- name: secrets
  secret:
    secretName: app-secrets
    defaultMode: 0400
```

### Projected Volume

```yaml
volumes:
- name: all-in-one
  projected:
    sources:
    - configMap:
        name: app-config
    - secret:
        name: app-secrets
    - serviceAccountToken:
        path: token
        expirationSeconds: 7200
```

Объединение множественных volume sources в один.

### CSI Volume

```yaml
volumes:
- name: csi-volume
  csi:
    driver: ebs.csi.aws.com
    volumeAttributes:
      fsType: ext4
```

### Downward API Volume

```yaml
volumes:
- name: podinfo
  downwardAPI:
    items:
    - path: labels
      fieldRef:
        fieldPath: metadata.labels
    - path: annotations
      fieldRef:
        fieldPath: metadata.annotations
```

---

## Volume Snapshots

### VolumeSnapshot

**VolumeSnapshot манифест:**

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: snapshot-pvc
spec:
  volumeSnapshotClassName: csi-snapclass
  source:
    persistentVolumeClaimName: pvc-data
```

### Просмотр VolumeSnapshot

```bash
kubectl get volumesnapshots
kubectl get volumesnapshot <n>
kubectl describe volumesnapshot <n>
```

### VolumeSnapshotClass

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-snapclass
driver: ebs.csi.aws.com
deletionPolicy: Delete
```

```bash
kubectl get volumesnapshotclasses
kubectl get volumesnapshotclass <n>
```

### Restore из Snapshot

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-restored
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  dataSource:
    name: snapshot-pvc
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

---

## Volume клонирование

### Clone PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-clone
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  dataSource:
    name: pvc-data
    kind: PersistentVolumeClaim
```

Клонирование создает новый PVC с копией данных исходного PVC.

---

## CSI Drivers

### Просмотр CSI Drivers

```bash
kubectl get csidrivers
kubectl get csidriver <n>
kubectl describe csidriver <n>
```

### CSI Nodes

```bash
kubectl get csinodes
kubectl get csinode <n>
kubectl describe csinode <n>
```

CSINode содержит информацию о CSI drivers на node.

---

## StatefulSet и Storage

### StatefulSet с volumeClaimTemplates

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 10Gi
      storageClassName: fast
```

VolumeClaimTemplate создает отдельный PVC для каждого pod replica.

**PVC naming для StatefulSet:**

```
<volumeClaimTemplate_name>-<statefulset_name>-<ordinal>
```

Пример: `data-web-0`, `data-web-1`, `data-web-2`

### Просмотр PVC для StatefulSet

```bash
kubectl get pvc -l app=web
```

---

## Storage проверки

### Проверка доступности storage

**Создание test pod с PVC:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pvc
spec:
  containers:
  - name: test
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: pvc-data
```

**Запись в volume:**

```bash
kubectl exec test-pvc -- sh -c "echo 'test data' > /data/test.txt"
kubectl exec test-pvc -- cat /data/test.txt
```

### Benchmark storage производительности

**FIO test:**

```bash
kubectl run fio --image=ljishen/fio --rm -it -- fio --name=seqwrite --rw=write --bs=1M --size=1G --numjobs=1 --directory=/data --group_reporting
```

Требует mounting volume в `/data`.

**DD test:**

```bash
kubectl exec <POD_NAME> -- dd if=/dev/zero of=/data/testfile bs=1M count=1024
kubectl exec <POD_NAME> -- dd if=/data/testfile of=/dev/null bs=1M
```

---

## Troubleshooting

### PVC застрял в Pending

**Проверка событий:**

```bash
kubectl describe pvc <n>
kubectl get events --field-selector involvedObject.name=<PVC_NAME>
```

**Распространенные причины:**

1. Нет доступных PV с matching параметрами
2. StorageClass не существует или неверный provisioner
3. Недостаточно ресурсов для динамического provisioning
4. Node selector constraints для local PV

**Проверка доступных PV:**

```bash
kubectl get pv
kubectl get pv -o jsonpath='{.items[?(@.status.phase=="Available")].metadata.name}'
```

**Проверка StorageClass:**

```bash
kubectl get sc
kubectl describe sc <STORAGECLASS_NAME>
```

### PV не освобождается

**Проверка reclaim policy:**

```bash
kubectl get pv <n> -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'
```

**Принудительное удаление PVC:**

```bash
kubectl patch pvc <n> -p '{"metadata":{"finalizers":null}}'
kubectl delete pvc <n> --force --grace-period=0
```

**Освобождение Released PV:**

```bash
kubectl patch pv <n> -p '{"spec":{"claimRef":null}}'
```

### Pod не может mount volume

**Проверка pod events:**

```bash
kubectl describe pod <POD_NAME>
kubectl get events --field-selector involvedObject.name=<POD_NAME>
```

**Распространенные ошибки:**

- `FailedMount`: Проблема с mounting volume на node
- `FailedAttachVolume`: Проблема с attach volume к node
- `VolumeBindingFailed`: PVC не может bind к PV

**Проверка node:**

```bash
kubectl describe node <NODE_NAME>
```

**Логи kubelet:**

```bash
journalctl -u kubelet -f
```

### Volume расширение не работает

**Проверка allowVolumeExpansion:**

```bash
kubectl get sc <STORAGECLASS_NAME> -o jsonpath='{.allowVolumeExpansion}'
```

Если false, расширение невозможно без пересоздания PVC.

**Проверка статуса расширения:**

```bash
kubectl describe pvc <n>
kubectl get pvc <n> -o jsonpath='{.status.conditions}'
```

**Требуется рестарт pod:**

Для некоторых volume types требуется перезапуск pod после изменения размера:

```bash
kubectl rollout restart deployment/<n>
```

### Storage performance проблемы

**Проверка IOPs и throughput:**

```bash
kubectl top nodes
kubectl describe node <NODE_NAME> | grep -A 5 "Allocated resources"
```

**Проверка volume type:**

```bash
kubectl get pv <n> -o jsonpath='{.spec.storageClassName}'
kubectl get sc <STORAGECLASS_NAME> -o yaml
```

Для высокой производительности использовать SSD-backed storage classes (gp3, pd-ssd).

### NFS mount проблемы

**Проверка NFS server доступности:**

```bash
kubectl run nfs-test --image=busybox -it --rm -- ping <NFS_SERVER_IP>
```

**Проверка NFS mount на node:**

```bash
mount | grep nfs
showmount -e <NFS_SERVER_IP>
```

**NFSv4 vs NFSv3:**

Проверить версию протокола в PV spec:

```yaml
nfs:
  server: <NFS_SERVER_IP>
  path: /exports
  mountOptions:
  - vers=4.1
```