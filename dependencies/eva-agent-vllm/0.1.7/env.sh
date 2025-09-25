#!/bin/sh

EA_PKG_VLLM_CHART_NAME=vllm-production-stack/vllm-stack
EA_PKG_VLLM_CHART_VER=0.1.7
EA_PKG_VLLM_REPO_NAME=vllm-production-stack
EA_PKG_VLLM_REPO_URL=https://vllm-project.github.io/production-stack

ea_pkg_vllm_update_repo() {
    helm repo add $EA_PKG_VLLM_REPO_NAME $EA_PKG_VLLM_REPO_URL
    helm repo update
}
