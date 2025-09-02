#!/bin/sh

EA_PKG_QDRANT_CHART_NAME=qdrant/qdrant
EA_PKG_QDRANT_CHART_VER=1.15.0
EA_PKG_QDRANT_REPO_NAME=qdrant
EA_PKG_QDRANT_REPO_URL=https://qdrant.github.io/qdrant-helm

ea_pkg_qdrant_update_repo() {
    helm repo add $EA_PKG_QDRANT_REPO_NAME $EA_PKG_QDRANT_REPO_URL
    helm repo update
}
