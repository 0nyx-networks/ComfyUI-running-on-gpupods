#!/bin/bash

set -Eeuo pipefail

# 通常のListen Address
LISTEN_ADDRESS=${LISTEN_ADDRESS:-"0.0.0.0"}

TAILSCALE_AUTHKEY=${TAILSCALE_AUTHKEY:-""}
TAILSCALE_HOSTNAME=${TAILSCALE_HOSTNAME:-"comfyui-gpupods1"}

# --- 1. ディレクトリ作成 ---
mkdir -p ${WORKSPACE}/data/.cache
mkdir -p ${WORKSPACE}/data/comfyui/custom_nodes
mkdir -p ${WORKSPACE}/data/models/{checkpoints,clip_vision,configs,controlnet,diffusion_models,unet,hypernetworks,loras,text_encoders,upscale_models,vae,audio_encoders,model_patches,latent_upscale_models}

declare -A MOUNTS

MOUNTS["/root/.cache"]="${WORKSPACE}/data/.cache"
MOUNTS["${WORKSPACE}/input"]="${WORKSPACE}/data/input"
MOUNTS["/comfyui/output"]="${WORKSPACE}/output"

for to_path in "${!MOUNTS[@]}"; do
    set -Eeuo pipefail
    from_path="${MOUNTS[${to_path}]}"
    rm -rf "${to_path}"
    if [ ! -d "${from_path}" ]; then
        mkdir -vp "${from_path}"
    fi
    mkdir -vp "$(dirname "${to_path}")"
    ln -sT "${from_path}" "${to_path}"
    echo Mounted "$(basename "${from_path}")"
done

# --- 2. Python venv activate & exec ---
source ${VENV_PATH}/bin/activate

# Upgrade torch to latest stable
if [ ${TORCH_PLATFORM:-"CUDA13.0"} = "CUDA13.0" ]; then
    uv pip install --upgrade "torch>=2.10.0" torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130
elif [ ${TORCH_PLATFORM:-"CUDA13.0"} = "CUDA12.8" ]; then
    uv pip install --upgrade "torch>=2.10.0" torchvision torchaudio
elif [ ${TORCH_PLATFORM:-"CUDA13.0"} = "CUDA12.6" ]; then
    uv pip install --upgrade "torch>=2.10.0" torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126
elif [ ${TORCH_PLATFORM:-"CUDA13.0"} = "ROCm7.1" ]; then
    uv pip install --upgrade "torch>=2.10.0" torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm7.1
else
    echo "Unsupported TORCH_PLATFORM: ${TORCH_PLATFORM}. Skipping torch upgrade."
fi

# Install ComfyUI requirements
pushd ${COMFYUI_DIR}
uv pip install -r requirements.txt
uv pip install -r manager_requirements.txt
popd

# --- 3. Print system info ---
echo "===== ComfyUI Entrypoint Info ====="
echo "Workspace: ${WORKSPACE}"
echo "Venv: ${VENV_PATH}"
echo "Python: $(which python) ($(python --version))"
echo "----- torch info -----"
python -c "import torch; print('torch=', torch.__version__); print('torch_cuda=', torch.version.cuda); print('avail=', torch.cuda.is_available())"

export TORCH_CUDA_AVAILABLE=$(python -c "import torch; print(torch.cuda.is_available())")
if [ "${TORCH_CUDA_AVAILABLE}" = "False" ]; then
    echo "CUDA is not available. Dropping to shell for debugging."
    echo "sleeping infinity..."
    sleep infinity
fi

# --- 4. カスタムノードをインストール ---

# ComfyUI の custom_nodes ディレクトリを workspace 内のものに置き換え
pushd ${COMFYUI_DIR}
uv pip install -r requirements.txt
uv pip install -r manager_requirements.txt
rm -rf custom_nodes 2>&1 >/dev/null
ln -s ${WORKSPACE}/data/comfyui/custom_nodes .
popd

# ComfyUI-Manager の設定ファイルを作成
mkdir -p ${COMFYUI_DIR}/user/__manager/
if [ ! -f ${COMFYUI_DIR}/user/__manager/config.ini ]; then
cat << '_EOL_' > ${COMFYUI_DIR}/user/__manager/config.ini
[default]
git_exe =
use_uv = True
channel_url = https://raw.githubusercontent.com/ltdrdata/ComfyUI-Manager/main
share_option = all
bypass_ssl = False
file_logging = True
update_policy = stable-comfyui
windows_selector_event_loop_policy = False
model_download_by_agent = False
downgrade_blacklist =
security_level = normal
always_lazy_install = False
network_mode = personal_cloud
db_mode = cache
verbose = False
_EOL_
fi

# comfy-cli をインストール
uv pip install comfy-cli
# 初回に Do you agree to enable tracking to improve the application? [y/N]: を聞かれるので自動で "N" を入力して設定する
echo "N" | comfy set-default ${COMFYUI_DIR}
comfy env

# Pixel Socket extensions for ComfyUI をインストール
#comfy node install pixel-socket-extensions-for-comfyui は別でComfyUI-Managerをインストールしないと動作しないため手動でインストール
pushd "${WORKSPACE}/data/comfyui/custom_nodes"
if [ ! -d "pixel-socket-extensions-for-comfyui" ] || [ "${FORCE_UPGRADE_CUSTOM_NODES:-'false'}" = "true" ] ; then
    echo "Installing/upgrading pixel-socket-extensions-for-comfyui..."
    rm -rf pixel-socket-extensions-for-comfyui >/dev/null 2>&1
    git clone -b main --depth 1 https://github.com/0nyx-networks/pixel-socket-extensions-for-comfyui.git
fi
cd pixel-socket-extensions-for-comfyui
uv pip install -r requirements.txt
popd

# Comfy NEKONOTE extensions をインストール
#comfy node install comfy-nekonote-extensions は別でComfyUI-Managerをインストールしないと動作しないため手動でインストール
pushd "${WORKSPACE}/data/comfyui/custom_nodes"
if [ ! -d "comfy-nekonote-extensions" ] || [ "${FORCE_UPGRADE_CUSTOM_NODES:-'false'}" = "true" ] ; then
    echo "Installing/upgrading comfy-nekonote-extensions..."
    rm -rf comfy-nekonote-extensions >/dev/null 2>&1
    git clone -b main --depth 1 https://github.com/0nyx-networks/comfy-nekonote-extensions.git
fi
cd comfy-nekonote-extensions
uv pip install -r requirements.txt
popd

# matrix-nio をインストール(ComfyUI-Manager 用)
uv pip install matrix-nio

# pynvml を nvidia-ml-py に置き換え
uv pip uninstall pynvml
uv pip install -U nvidia-ml-py

# --- 5. safetensors の自動ダウンロード機能 ---
export DOWNLOAD_LIST="/container/download_list.txt"
export CHECKSUM_LIST="/container/checksum_list.txt"
export DOWNLOAD_DIR="${WORKSPACE}/data/models"

rm -f "${DOWNLOAD_LIST}" >/dev/null 2>&1
rm -f "${CHECKSUM_LIST}" >/dev/null 2>&1

# Custom user lists
if [ -f "${DOWNLOAD_DIR}/download_list.txt" ]; then
    echo "Custom download list found in download directory. Appending to download list."
    cat "${DOWNLOAD_DIR}/download_list.txt" >> "${DOWNLOAD_LIST}"
fi
if [ -f "${DOWNLOAD_DIR}/checksum_list.txt" ]; then
    echo "Custom checksum list found in download directory. Appending to checksum list."
    cat "${DOWNLOAD_DIR}/checksum_list.txt" >> "${CHECKSUM_LIST}"
fi

if [ -f "${DOWNLOAD_LIST}" ]; then
    echo "${DOWNLOAD_LIST} found. Starting aria2c downloads..."
    mkdir -p "$DOWNLOAD_DIR"

    aria2c \
        --continue=true \
        --allow-overwrite=false \
        --auto-file-renaming=false \
        --max-connection-per-server=4 \
        --split=16 \
        --dir="${DOWNLOAD_DIR}" \
        --input-file="${DOWNLOAD_LIST}"

    echo "Download finished."
else
    echo "No ${DOWNLOAD_LIST} found. Skipping download."
fi

if [ -f "${CHECKSUM_LIST}" ]; then
    echo "${CHECKSUM_LIST} found. Starting sha256sum verification..."

    grep -E -v '^[#|;]' "${CHECKSUM_LIST}" | parallel --will-cite -n1 'echo -n {} | sha256sum -c'

    echo "Checksum verification finished."
else
    echo "No ${CHECKSUM_LIST} found. Skipping checksum verification."
fi

# --- 6. startup.sh があれば実行 ---
if [ -f "${WORKSPACE}/comfyui/startup.sh" ]; then
    pushd ${WORKSPACE}/comfyui
    . ${WORKSPACE}/comfyui/startup.sh
    popd
fi

# --- 7. Tailscale setup ---
if [ -z "${TAILSCALE_AUTHKEY}" ] || [ -z "${TAILSCALE_HOSTNAME}" ]; then
    echo "TAILSCALE_AUTHKEY or TAILSCALE_HOSTNAME is not set. Skipping Tailscale setup."
else
    echo "TAILSCALE_AUTHKEY and TAILSCALE_HOSTNAME are set. Setting up Tailscale..."
    # Tailscale を利用する場合は起動
    tailscaled --tun=userspace-networking --state=/tmp/tailscale.state &

    # tailscaled ready待ち
    until tailscale status >/dev/null 2>&1; do
    sleep 1
    done

    tailscale up \
    --authkey=${TAILSCALE_AUTHKEY} \
    --hostname=${TAILSCALE_HOSTNAME} \
    --advertise-tags=tag:comfyui-running-on-gpupods \
    --accept-routes \
    --reset

    echo "Tailscale setup completed. Current IPs:"
    tailscale ip -4

    LISTEN_ADDRESS="127.0.0.1"
fi

# --- 6. ComfyUI start ---
pushd ${COMFYUI_DIR}
echo "***** Starting ${NUMBER_OF_GPUS} ComfyUI processes *****"
LISTEN_PORT=${LISTEN_PORT:-8188}
for ((idx=0; idx<${NUMBER_OF_GPUS}; idx++)); do
    CURRENT_PORT=$(($LISTEN_PORT + $idx))

    # Tailscale を利用する場合は、各プロセスをローカルで待ち受けさせ、Tailscale の serve コマンドで公開する
    if [ -z "${TAILSCALE_AUTHKEY}" ] || [ -z "${TAILSCALE_HOSTNAME}" ]; then
        tailscale serve http://${LISTEN_ADDRESS}:${CURRENT_PORT}
    fi

    echo "***** Starting ComfyUI process $(($idx+1))/${NUMBER_OF_GPUS} on port ${CURRENT_PORT} with GPU ${idx} *****"
    CUDA_VISIBLE_DEVICES=${idx} python3 -u main.py --listen ${LISTEN_ADDRESS} --port ${CURRENT_PORT} ${CLI_ARGS} &
done
popd

wait
