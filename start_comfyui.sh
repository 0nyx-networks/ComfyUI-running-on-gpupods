#!/bin/bash

# ComfyUI tag initial value
export COMFYUI_TAG="v0.14.2"

if [ -f ./env ]; then
  set -a
  source ./env
  set +a
fi

# ComfyUIのコンテナを実行(1GPU想定)
podman container run -d --replace \
  --name comfyui-running-on-gpupods \
  -p 8188:8188 \
  --volume "$(pwd)/data:/workspace" \
  --device "nvidia.com/gpu=all" \
  --env NUMBER_OF_GPUS=1 \
  localhost/comfyui-running-on-gpupods:${COMFYUI_TAG:-"latest"}

podman container logs -f comfyui-running-on-gpupods
