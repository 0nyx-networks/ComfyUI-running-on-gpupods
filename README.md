# ComfyUI running on gpupods

[![Build and Push DockerHub](https://github.com/0nyx-networks/ComfyUI-running-on-gpupods/actions/workflows/build-and-push-dockerhub.yml/badge.svg)](https://github.com/0nyx-networks/ComfyUI-running-on-gpupods/actions/workflows/build-and-push-dockerhub.yml)

This repository provides a setup to run [ComfyUI](https://github.com/comfyanonymous/ComfyUI) on a Linux container using Podman/Docker.

## Prerequisites
- gpupods account with a GPU container
- GPU container with at NVIDIA RTX 4090/5090 or equivalent GPU
- CUDA 13.0 or later drivers installed on the GPU container

## Cloud Running Instructions
1. Pull the latest ComfyUI image from DockerHub
```bash
podman pull docker.io/m10i1986/comfyui-running-on-gpupods:latest
```

## Local Running Instructions
1. Clone this repository to your local machine or directly to your gpupods container.
```bash
git clone https://github.com/0nyx-networks/ComfyUI-running-on-gpupods.git
cd ComfyUI-running-on-gpupods
```

2. (Optional) Create an `env` file to specify the ComfyUI version you want to use. If not specified, it will use the default version defined in the `build.sh` script.
```bash
echo "COMFYUI_TAG=v0.14.2" > env
```

3. Build the ComfyUI container.
```bash
./build.sh
```

4. Run the ComfyUI container.
```bash
./start_comfyui.sh
```

## Upload models and extensions
- Directory for models: `/workspace/data/models/`
- Directory for extensions: `/workspace/data/comfyui/custom_nodes/`

## Thanks

Special thanks to everyone behind these awesome projects, without them, none of this would have been possible:

- [ComfyUI](https://github.com/comfyanonymous/ComfyUI)
