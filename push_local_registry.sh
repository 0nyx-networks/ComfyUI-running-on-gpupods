#!/bin/bash

export PRIVATE_REGISTRY_URL=${PRIVATE_REGISTRY_URL:-'registry.foundation0.link'}

# ComfyUI tag initial value
export COMFYUI_TAG=""

if [ -f ./env ]; then
  set -a
  source ./env
  set +a
fi

podman login ${PRIVATE_REGISTRY_URL}

podman tag comfyui-running-on-gpupods:${COMFYUI_TAG:-"latest"} ${PRIVATE_REGISTRY_URL}/comfyui-running-on-gpupods:${COMFYUI_TAG:-"latest"}
podman push ${PRIVATE_REGISTRY_URL}/comfyui-running-on-gpupods:${COMFYUI_TAG:-"latest"}
podman tag ${PRIVATE_REGISTRY_URL}/comfyui-running-on-gpupods:${COMFYUI_TAG:-"latest"} ${PRIVATE_REGISTRY_URL}/comfyui-running-on-gpupods:latest
podman push ${PRIVATE_REGISTRY_URL}/comfyui-running-on-gpupods:latest
podman image rm ${PRIVATE_REGISTRY_URL}/comfyui-running-on-gpupods:latest
podman image rm ${PRIVATE_REGISTRY_URL}/comfyui-running-on-gpupods:${COMFYUI_TAG:-"latest"}
