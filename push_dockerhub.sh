#!/bin/bash

export DOCKER_USERNAME=${DOCKER_USERNAME:-'m10i1986'}
export DOCKER_PASSWORD=${DOCKER_PASSWORD:-''}

# ComfyUI tag initial value
export COMFYUI_TAG="v0.14.2"

if [ -f ./env ]; then
  set -a
  source ./env
  set +a
fi

podman login -u "${DOCKER_USERNAME}" -p "${DOCKER_PASSWORD}" docker.io

podman tag comfyui-running-on-gpupods:${COMFYUI_TAG:-"latest"} docker.io/${DOCKER_USERNAME}/comfyui-running-on-gpupods:${COMFYUI_TAG:-"latest"}
podman push --format=docker docker.io/${DOCKER_USERNAME}/comfyui-running-on-gpupods:${COMFYUI_TAG:-"latest"}
podman tag docker.io/${DOCKER_USERNAME}/comfyui-running-on-gpupods:${COMFYUI_TAG:-"latest"} docker.io/${DOCKER_USERNAME}/comfyui-running-on-gpupods:latest
podman push --format=docker docker.io/${DOCKER_USERNAME}/comfyui-running-on-gpupods:latest
podman image rm docker.io/${DOCKER_USERNAME}/comfyui-running-on-gpupods:latest
podman image rm docker.io/${DOCKER_USERNAME}/comfyui-running-on-gpupods:${COMFYUI_TAG:-"latest"}

podman logout docker.io
