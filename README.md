# ComfyUI running on gpupods

[![Build and Push DockerHub](https://github.com/0nyx-networks/ComfyUI-running-on-gpupods/actions/workflows/build-and-push-dockerhub.yml/badge.svg)](https://github.com/0nyx-networks/ComfyUI-running-on-gpupods/actions/workflows/build-and-push-dockerhub.yml)

このリポジトリは、[ComfyUI](https://github.com/comfyanonymous/ComfyUI)をPodman/Dockerを使用してLinuxコンテナ上で実行するためのセットアップを提供します。GPU Pods環境での運用を想定した構成となっており、NVIDIA GPUを活用した高速な画像生成が可能です。

## 概要

ComfyUI running on gupupodsは、クラウドGPU環境でComfyUIを簡単にセットアップ・実行するためのプロジェクトです。  
Dockerイメージの自動ビルドとDockerHubへの自動プッシュを備えており、クラウド環境およびローカル環境の両方での実行に対応しています。

## GPU Cloud with Verified Compatibility
- [Runpod](https://www.runpod.io/) : Public Template有
- [SimplePod](https://simplepod.ai/)

### 特徴

- **簡単なセットアップ**: スクリプトベースの自動化されたビルド・実行プロセス
- **GPU対応**: NVIDIA GPUを活用した高速処理
- **フレキシブルなバージョン管理**: ComfyUIのバージョンを自由に指定可能
- **モデル・エクステンション対応**: 複数の生成モデル（FLUX、Qwen、LTX等）に対応
- **継続的デプロイメント**: GitHub Actionsによる自動ビルド・プッシュ

## 必要な環境

### ハードウェア要件

- **GPU**: NVIDIA RTX 4090/5090 以上相当のGPU
- **VRAM**: 最低24GB推奨（一部モデルは48GB以上推奨）
- **ストレージ**: 50GB以上（モデルダウンロード用）

### ソフトウェア要件

- **OS**: Linux（Ubuntu 24.04推奨）
- **コンテナランタイム**: Podman または Docker
- **NVIDIA環境**:
  - NVIDIA CUDA 13.0 以上
  - NVIDIA Container Runtime
  - NVIDIA Driver（最新版推奨）
- **その他**: Git、curl、wget

### クラウド環境での実行

- gpupods アカウント
- GPU コンテナリソース

## インストール方法

### 1. リポジトリのクローン

```bash
git clone https://github.com/0nyx-networks/ComfyUI-running-on-gpupods.git
cd ComfyUI-running-on-gpupods
```

### 2. 環境設定（オプション）

`env` ファイルを作成して、ComfyUIのバージョンや追加設定を指定できます。

```bash
cp env.sample env
# envファイルを編集して設定を変更
vi env
```

**環境変数の説明** ([env.sample](env.sample) より):

- `COMFYUI_TAG`: ComfyUIのバージョンタグ（デフォルト: v0.14.2）

### 3. コンテナイメージのビルド

```bash
./build.sh
```

デフォルトではComfyUI v0.14.2でビルドされます。別のバージョンを指定する場合：

```bash
echo "COMFYUI_TAG=v0.16.0" > env
./build.sh
```

### 4. コンテナの実行

```bash
./start_comfyui.sh
```

コンテナが起動し、ComfyUI UIにアクセス可能になります。

## 使用方法

### WebUIへのアクセス

コンテナ起動後、以下のURLでComfyUI WebUIにアクセスしてください：

```
http://localhost:8188
```

### モデルのアップロード

モデルファイルは以下のディレクトリに配置してください：

```
./data/models/
```

コンテナ内の対応パス：

```
/workspace/data/models/
```

### カスタムノードの導入

ComfyUIカスタムノードは以下のディレクトリに配置：

```
./data/comfyui/custom_nodes/
```

コンテナ内の対応パス：

```
/workspace/data/comfyui/custom_nodes/
```

### 出力結果

生成された画像などの出力ファイルは以下に保存されます：

```
./output/
```

### コンテナの停止

```bash
./stop_comfyui.sh
```

### クラウド実行（DockerHub から）

私がビルドしたイメージは、DockerHubで公開しています。  
https://hub.docker.com/r/m10i1986/comfyui-running-on-gpupods

DockerHubから最新のイメージを直接実行することも可能です：
```bash
podman pull docker.io/m10i1986/comfyui-running-on-gpupods:latest
podman container run -d --replace \
  --name comfyui-running-on-gpupods \
  -p 8188:8188 \
  --volume "$(pwd)/data:/workspace/data" \
  --volume "$(pwd)/output:/workspace/output" \
  --device "nvidia.com/gpu=all" \
  --env NUMBER_OF_GPUS=1 \
  docker.io/m10i1986/comfyui-running-on-gpupods:latest
```

## プロジェクト構成

```
.
├── build.sh                         # コンテナイメージビルドスクリプト
├── start_comfyui.sh                 # コンテナ起動スクリプト
├── stop_comfyui.sh                  # コンテナ停止スクリプト
├── env.sample                       # 環境変数サンプルファイル
├── data/                            # モデル・カスタムノードのマウント先
├── output/                          # 出力ファイル格納ディレクトリ
├── services/
│   └── comfyui/
│       ├── Containerfile            # Docker/Podman イメージビルド定義
│       ├── entrypoint.sh            # コンテナ起動スクリプト
│       └── extra_model_paths.yaml   # ComfyUI モデルパス設定
├── LICENSE                          # MIT ライセンス
└── README.md                        # このファイル
```

## 実装概要

### ビルドプロセス

`build.sh` スクリプトは以下を実行します：

1. `env` ファイルから環境変数を読み込み（存在する場合）
2. ComfyUIタグを決定（デフォルト: v0.14.2）
3. Containerfileを使用してDockerイメージをビルド
4. NVIDIA GPUドライバー対応を有効化

### Dockerコンテナ構成

Containerfileは以下の処理を実施します：

1. **ベースイメージ**: Ubuntu 24.04
2. **依存パッケージのインストール**: curl、wget、git、aria2等
3. **Python 3.13環境構築**: uvを使用した仮想環境
4. **ComfyUIのインストール**: 指定タグのComfyUIをgitからクローン
5. **NVIDIA環境設定**: GPUドライバー、CUDA対応
6. **ポート公開**: 8188番ポート（デフォルトWebUI）

### 実行時設定

起動時に以下の環境変数が設定されます：

- `NVIDIA_VISIBLE_DEVICES=all`: すべてのGPUを可視化
- `NVIDIA_DRIVER_CAPABILITIES=compute,utility`: 計算・ユーティリティ機能を有効化
- `NUMBER_OF_GPUS`: 使用するGPU数（デフォルト: 1）
- `CLI_ARGS`: ComfyUI実行オプション（`--dont-print-server --enable-manager`）

## トラブルシューティング

### コンテナが起動しない

```bash
# ログを確認
podman logs comfyui-running-on-gpupods

# コンテナを削除して再実行
podman container rm comfyui-running-on-gpupods
./start_comfyui.sh
```

### GPUが認識されない

```bash
# NVIDIAドライバおよびランタイムの確認
nvidia-smi
podman run --rm --device nvidia.com/gpu=all nvidia/cuda:13.0-runtime nvidia-smi
```

### メモリ不足エラー

- 使用するモデルの仕様を確認
- より大きなVRAMを備えたGPUを使用

## 技術スタック

| カテゴリ | 技術 |
|---------|------|
| **ベースOS** | Ubuntu 24.04 |
| **コンテナ化** | Docker/Podman |
| **プログラミング言語** | Python 3.13 |
| **パッケージ管理** | uv (Astral) |
| **GPU対応** | NVIDIA CUDA 13.0+、NVIDIA Container Runtime |
| **WebフレームワークPython** | Python（ComfyUI付属） |
| **ファイルダウンロード** | aria2、wget、curl |

## ライセンス

このプロジェクトはMIT Licenseの下で公開されています。詳細は[LICENSE](LICENSE)ファイルを参照してください。

```
MIT License

Copyright (c) 2025 MINETA "m10i" Hiroki
```

## 作者

- **MINETA "m10i" Hiroki** - 初期開発・保守

## 謝辞

このプロジェクトは以下の素晴らしいオープンソースプロジェクトの上に成り立っています：

- [ComfyUI](https://github.com/comfyanonymous/ComfyUI) - ノードベースのUI/API優先のStable Diffusion Web UI
- [Podman](https://podman.io/) - Linux上のコンテナエンジン
- [NVIDIA Container Runtime](https://github.com/NVIDIA/nvidia-container-runtime) - GPU対応コンテナ実行環境

## 関連リンク

- [ComfyUI公式リポジトリ](https://github.com/comfyanonymous/ComfyUI)
- [NVIDIA CUDA](https://developer.nvidia.com/cuda-downloads)

## 質問・フィードバック

質問や提案がある場合は、GitHubのIssuesセクションで報告してください。
