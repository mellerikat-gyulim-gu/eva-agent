# eva-agent
eva agent and related helm charts

## Requirements

- Kubernetes: >= 1.16.0-0 for CPU only
- Kubernetes: >= 1.26.0-0 for GPU stable support (NVIDIA and AMD)
- Namespace(`eva-agent`) and service account(`sa-eva-agent`) for eva-agent
- Storage infra for qdrant and ollama

## Dependencies
| eva-agent | eva-agent-qdrant | eva-agent-ollama | eva-agent-init |
|---|---|---|---|
| app-2.1.1 (2.1.1) | app-1.15.0 (1.15.0) | app-0.11.4 (1.15.0) | app-1.0.0 (1.0.0) |

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
cp -r ./values.tpl/eva-agent-init/app-{app version} .values-{postfix you want}

# Modify values in .values-{postfix you want} to your environment.

helm repo add eva-agent https://mellerikat.github.io/eva-agent/
helm repo update

# {chart version} and {app version} are same until now.
helm install eva-agent-init eva-agent \
    -n {namespace} --version {chart version} \
    -f .values-{postfix you want}/eva-agent-init/values.yaml \
    -f .values-{postfix you want}/eva-agent-init/values-{platform}.yaml
```

### Install dependencies - eva-agent-qdrant, eva-agent-ollama

```sh
cp -r ./dependencies/eva-agent-qdrant/app-{app version} .values-{postfix you want}

# Modify values in .values-{postfix you want} to your environment.

# import env vars on helm repo
source .values-{postfix you want}/env.sh
# update helm repo
ea_pkg_qdrant_update_repo
# install helm package
helm install eva-agent-qdrant $EA_PKG_QDRANT_CHART_NAME \
    -n {namespace} --version $EA_PKG_QDRANT_CHART_VER \
    -f .values-{postfix you want}/values.yaml \
    -f .values-{postfix you want}/{patch version}/values.yaml \
    -f .values-{postfix you want}/{patch version}/values-{platform}.yaml
```

```sh
cp -r ./dependencies/eva-agent-ollama/app-{app version} .values-{postfix you want}

# Modify values in .values-{postfix you want} to your environment.

# import env vars on helm repo
source .values-{postfix you want}/env.sh
# update helm repo
ea_pkg_ollama_update_repo
# install helm package
helm install eva-agent-ollama $EA_PKG_OLLAMA_CHART_NAME \
    -n {namespace} --version $EA_PKG_OLLAMA_CHART_VER \
    -f .values-{postfix you want}/values.yaml \
    -f .values-{postfix you want}/{patch version}/values.yaml \
    -f .values-{postfix you want}/{patch version}/values-{platform}.yaml
```

### Install eva-agent

eva-agent is main service.

```sh
cp -r ./secrets.tpl/eva-agent/app-{app version} .values-{postfix you want}

# Modify values in .values-{postfix you want} to your environment.

helm repo add eva-agent https://mellerikat.github.io/eva-agent/
helm repo update

# {chart version} and {app version} are same until now.
helm install eva-agent eva-agent \
    -n {namespace} --version {chart version} \
    -f .values-{postfix you want}/eva-agent/secret-values.yaml \
    -f .values-{postfix you want}/eva-agent/values.yaml \
    -f .values-{postfix you want}/eva-agent/values-{platform}.yaml
```
