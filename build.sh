#!/bin/bash

set -Eeuo pipefail

# ComfyUI tag initial value
export COMFYUI_TAG="v0.14.2"

if [ -f ./env ]; then
  set -a
  source ./env
  set +a
fi

# ComfyUIのコンテナをビルド
podman build -t comfyui-running-on-gpupods:${COMFYUI_TAG} \
  --force-rm \
  --build-arg COMFYUI_TAG=${COMFYUI_TAG} \
  --device "nvidia.com/gpu=all" \
  ./services/comfyui/
