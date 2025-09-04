#!/bin/sh

EA_PKG_OLLAMA_CHART_NAME=otwld/ollama
EA_PKG_OLLAMA_CHART_VER=1.27.0
EA_PKG_OLLAMA_REPO_NAME=otwld
EA_PKG_OLLAMA_REPO_URL=https://helm.otwld.com/

ea_pkg_ollama_update_repo() {
    helm repo add $EA_PKG_OLLAMA_REPO_NAME $EA_PKG_OLLAMA_REPO_URL
    helm repo update
}
