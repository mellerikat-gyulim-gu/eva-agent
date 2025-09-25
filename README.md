# eva-agent
eva agent and related helm charts

## Requirements

- Kubernetes: >= 1.16.0-0 for CPU only
- Kubernetes: >= 1.26.0-0 for GPU stable support (NVIDIA and AMD)
- Namespace(eg. `eva-agent`) and service account(eg. `sa-eva-agent`) for eva-agent
- Storage infra for qdrant and ollama
- AWS ECR pull permission for eva-agent image
- (On-premise) k3 and gpu setups - refer Appendix

## Dependencies

`eva-agent` depends on `eva-agent-ollama` OR `eva-agent-vllm`. So they should be installed exclusively.

| eva-agent                        | eva-agent-qdrant    | eva-agent-ollama    | eva-agent-init    |
| ---- | ---- | ---- | ---- |
| 2.1.2 / app-2.1.1 / img-2.1-a1.1 |                     |                     |                   |
| 2.1.1 / app-2.1.1 / img-2.1-a1.1 | 1.15.0 / app-1.15.0 | 1.27.0 / app-0.11.4 | 1.0.0 / app-1.0.0 |

## Changes

eva-agent - 2.1.2
- values `dockerConfig.json` added to imagePullSecret.

## Installation

### Clone eva-agent helm repository

It includes values templates in addition to charts.

```sh
git clone https://github.com/mellerikat/eva-agent.git
cd eva-agent
```

### Install eva-agent-init

Initializes and defines resources for eva-agent package.
Should be installed once.

```sh
cp -r values.tpl/eva-agent-init/{chart version} .values-{postfix}

# Modify values in .values-{postfix} to your environment.

helm repo add eva-agent https://mellerikat.github.io/eva-agent/
helm repo update

# {chart version} and {app version} are same until now.
helm install eva-agent-init eva-agent/eva-agent-init \
    -n {namespace} --version {chart version} \
    -f .values-{postfix}/values.yaml \
    -f .values-{postfix}/values-{platform}.yaml
```

### Install dependencies

#### Install eva-agent-qdrant

```sh
cp -r dependencies/eva-agent-qdrant/app-{app version} .values-{postfix}

# Modify values in .values-{postfix} to your environment.

# import env vars on helm repo
source .values-{postfix}/env.sh
# update helm repo
ea_pkg_qdrant_update_repo
# install helm package
helm install eva-agent-qdrant $EA_PKG_QDRANT_CHART_NAME \
    -n {namespace} --version $EA_PKG_QDRANT_CHART_VER \
    -f .values-{postfix}/values.yaml \
    -f .values-{postfix}/values-{platform}.yaml
```

#### Install eva-agent-ollama

```sh
cp -r dependencies/eva-agent-ollama/app-{app version} .values-{postfix}

# Modify values in .values-{postfix} to your environment.

# import env vars on helm repo
source .values-{postfix}/env.sh
# update helm repo
ea_pkg_ollama_update_repo
# install helm package
helm install eva-agent-ollama $EA_PKG_OLLAMA_CHART_NAME \
    -n {namespace} --version $EA_PKG_OLLAMA_CHART_VER \
    -f .values-{postfix}/values.yaml \
    -f .values-{postfix}/values-{platform}.yaml
```
If you want to use persistence storage of AWS EBS or host-path,
you might apply additional following values template.

`dependencies/eva-agent-ollama/app-{app version}/values-k3s-bs.yaml`

As you can see, `nodeSelector` should be defined for PVC initialization would be provisioned dynamically.

#### Install eva-agent-vllm

`kustomize` required.
Install `kustomize` as following.
```sh
sudo snap install kustomize
```

```sh
cp -r dependencies/eva-agent-vllm/{chart version} .values-{postfix}

# Modify values in .values-{postfix} to your environment.

# import env vars on helm repo
source .values-{postfix}/env.sh
# update helm repo
ea_pkg_vllm_update_repo
# install helm package
post_renderer_sh=.values-{postfix}/post-renderer.sh
chmod +x $post_renderer_sh
helm install eva-agent-vllm $EA_PKG_VLLM_CHART_NAME \
    -n {namespace} --version $EA_PKG_VLLM_CHART_VER \
    --post-renderer $post_renderer_sh \
    -f .values-{postfix}/values.yaml \
    -f .values-{postfix}/values-{platform}.yaml
```

### Install eva-agent

eva-agent is main service.

Default image repository is AWS ECR and need credential setting before install or upgrade.
You should login AWS ECR with access key and secret key which had been provided by us.
(Chart version >= 2.1.2)

For example...
Fill AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY up.
```sh
AWS_ECR_REGION=ap-northeast-2
AWS_ECR_HOST=339713051385.dkr.ecr.${AWS_ECR_REGION}.amazonaws.com
export AWS_ACCESS_KEY_ID={fill up}
export AWS_SECRET_ACCESS_KEY={fill up}

# needs aws CLI

aws ecr get-login-password \
    --region $AWS_ECR_REGION \
        | docker login --username AWS --password-stdin $AWS_ECR_HOST
docker_config_file="$HOME/.docker/config.json"
# $HOME/.docker/config.json should be created or updated

values_file="$HOME/.docker/config-values.yaml"
cat > "$values_file" << EOF
dockerConfig:
  json: $(cat "$docker_config_file" | base64 -w0)
EOF
# $HOME/.docker/config-values.yaml should be created or updated
```
```sh
cp -r values.tpl/eva-agent/{chart version} .values-{postfix}

# Modify values in .values-{postfix} to your environment.

helm repo add eva-agent https://mellerikat.github.io/eva-agent/
helm repo update

# $HOME/.docker/config-values.yaml should be refreshed before install or upgrade
helm install eva-agent eva-agent/eva-agent \
    -n {namespace} --version {chart version} \
    -f "$HOME/.docker/config-values.yaml" \
    -f .values-{postfix}/secret-values.yaml \
    -f .values-{postfix}/values.yaml \
    -f .values-{postfix}/values-{platform}.yaml
```

## Appendix A. On-premise - k3s setup

### Envirionment
- Ubuntu 22 LTS

### Install k3s

```sh
# Install docker on k3s nodes if needed
# curl https://releases.rancher.com/install-docker/20.10.sh | sh

# Install k3s using docker not containerd
curl -sfL https://get.k3s.io | sudo sh -s - --docker
```

### kubectl setup for k3s

```sh
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -un):$(id -gn) $HOME/.kube/config

# concat "export KUBECONFIG=$HOME/.kube/config" to $HOME/.bashrc and restart shell or "source $HOME/.bashrc"

kubectl version
# Client Version: v1.33.4+k3s1
# Kustomize Version: v5.6.0
# Server Version: v1.33.4+k3s1
```

### Install helm

```sh
sudo snap install helm --classic
```

### Setup nvidia gpu binding

Refer `Appendix B. On-premise - nvidia gpu setup for k3s`

### Install NFS CSI Driver for storageclass of fileSystem

Refer https://github.com/kubernetes-csi/csi-driver-nfs

```sh
helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm repo update
helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs --namespace kube-system --version v4.11.0
```

### Install NFS server and exports Host OS

```sh
sudo apt update
sudo apt install nfs-kernel-server -y

sudo mkdir -p /share/eva-agent
sudo chown nobody:nogroup /share/eva-agent
sudo chmod 777 /share/eva-agent

echo "/share/eva-agent *(rw,async,no_subtree_check,no_root_squash,insecure)" | sudo tee -a /etc/exports

sudo exportfs -ra
sudo systemctl restart nfs-kernel-server

# test
showmount -e localhost
sudo mkdir /mnt/tmp && sudo mount -t nfs -o rw,nfsvers=4 10.158.2.73:/share/eva-agent /mnt/tmp
sudo umount /mnt/tmp
```

### Create namespace and serviceaccount

```sh
kubectl create namespace eva-agent
kubectl create serviceaccount sa-eva-agent -n eva-agent
```

### Uninstall k3s

```sh
sudo /usr/local/bin/k3s-uninstall.sh

# manually or confirmed
sudo rm -rf /etc/rancher/k3s
sudo rm -rf /var/lib/rancher/k3s
sudo rm -rf /var/lib/kubelet
sudo rm -rf /etc/systemd/system/k3s*
```

## Appendix B. On-premise - nvidia gpu setup for k3s

### Setup Ubuntu nvidia driver

```sh
# (Optional) Uninstall previous nvidia driver if needed
sudo apt update
sudo apt purge nvidia*

sudo apt update
sudo ubuntu-drivers autoinstall  # recommend

sudo reboot
```

```sh
# Install nvidia container toolkit and cuda toolkit
# Refer:
# https://documentation.ubuntu.com/server/how-to/graphics/install-nvidia-drivers/index.html
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html

sudo apt-get update
sudo apt-get install -y nvidia-docker2

sudo nvidia-ctk runtime configure --runtime=docker

# Add "default-runtime": "nvidia" in /etc/docker/daemon.json as following
#
# {
#     "default-runtime": "nvidia",
#     "runtimes": {
#         "nvidia": {
#             "args": [],
#             "path": "nvidia-container-runtime"
#         }
#     }
# }
sudo vi /etc/docker/daemon.json

sudo vi /var/lib/rancher/k3s/agent/etc/containerd/config.toml
# [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
#   runtime_type = "io.containerd.runc.v2"
#   privileged_without_host_devices = false
#   [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
#     BinaryName = "/usr/bin/nvidia-container-runtime"

sudo systemctl restart docker
sudo systemctl restart k3s  # if needed
```

Check nvidia gpu setup as following and setup as your own way if needed.
```sh
which nvidia-ctk
# /usr/bin/nvidia-ctk

nvcc -V
# nvcc: NVIDIA (R) Cuda compiler driver
# Copyright (c) 2005-2021 NVIDIA Corporation
# Built on Thu_Nov_18_09:45:30_PST_2021
# Cuda compilation tools, release 11.5, V11.5.119
# Build cuda_11.5.r11.5/compiler.30672275_0

docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
# +-----------------------------------------------------------------------------------------+
# | NVIDIA-SMI 575.64.03              Driver Version: 575.64.03      CUDA Version: 12.9     |
# |-----------------------------------------+------------------------+----------------------+
# | GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
# | Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
# |                                         |                        |               MIG M. |
# |=========================================+========================+======================|
# |   0  NVIDIA GeForce GTX 1080        Off |   00000000:03:00.0 Off |                  N/A |
# | 28%   35C    P8              6W /  180W |      40MiB /   8192MiB |      0%      Default |
# |                                         |                        |                  N/A |
# +-----------------------------------------+------------------------+----------------------+

# +-----------------------------------------------------------------------------------------+
# | Processes:                                                                              |
# |  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
# |        ID   ID                                                               Usage      |
# |=========================================================================================|
# +-----------------------------------------------------------------------------------------+

```

### Install nvidia-device-plugin in k3s

```sh
# install
kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.1/deployments/static/nvidia-device-plugin.yml

# check

kubectl get all -n kube-system
# NAME                                          READY   STATUS      RESTARTS      AGE
# ...
# pod/nvidia-device-plugin-daemonset-9kp44      1/1     Running     0             37s
# ...
# NAME                                            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
# daemonset.apps/nvidia-device-plugin-daemonset   1         1         1       1            1           <none>          37s

kubectl logs pod/nvidia-device-plugin-daemonset-9kp44 -n kube-system
# ...
# I0910 06:21:55.093864       1 main.go:238] Starting FS watcher for /var/lib/kubelet/device-plugins
# I0910 06:21:55.093941       1 main.go:245] Starting OS watcher.
# I0910 06:21:55.094252       1 main.go:260] Starting Plugins.
# I0910 06:21:55.094285       1 main.go:317] Loading configuration.
# I0910 06:21:55.095184       1 main.go:342] Updating config with default resource matching patterns.
# I0910 06:21:55.095404       1 main.go:353]
# Running with config:
# ...
# I0910 06:21:55.095418       1 main.go:356] Retrieving plugins.
# I0910 06:21:55.121068       1 server.go:195] Starting GRPC server for 'nvidia.com/gpu'
# I0910 06:21:55.121858       1 server.go:139] Starting to serve 'nvidia.com/gpu' on /var/lib/kubelet/device-plugins/nvidia-gpu.sock
# I0910 06:21:55.124657       1 server.go:146] Registered device plugin for 'nvidia.com/gpu' with Kubelet

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  restartPolicy: Never
  containers:
    - name: cuda-container
      image: nvcr.io/nvidia/k8s/cuda-sample:vectoradd-cuda12.5.0
      resources:
        limits:
          nvidia.com/gpu: 1 # requesting 1 GPU
EOF

kubectl logs gpu-pod
# [Vector addition of 50000 elements]
# Copy input data from the host memory to the CUDA device
# CUDA kernel launch with 196 blocks of 256 threads
# Copy output data from the CUDA device to the host memory
# Test PASSED
# Done

kubectl delete pod gpu-pod

# uninstall
# kubectl delete -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.1/deployments/static/nvidia-device-plugin.yml
```
