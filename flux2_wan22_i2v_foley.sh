#!/bin/bash
set -euo pipefail

# ============================================================
# Flux 2 img2img + Wan 2.2 I2V + HunyuanFoley — ALL weights
# Template hash: a7c3f1d2e8b04956c1d3a2f7e9b81234
# Total: ~72 GB
# ============================================================

WORKSPACE_DIR="${WORKSPACE:-/workspace}"
COMFYUI_DIR="${WORKSPACE_DIR}/ComfyUI"
MODELS_DIR="${COMFYUI_DIR}/models"
CUSTOM_NODES_DIR="${COMFYUI_DIR}/custom_nodes"

mkdir -p \
  "$MODELS_DIR/text_encoders" \
  "$MODELS_DIR/vae" \
  "$MODELS_DIR/diffusion_models" \
  "$MODELS_DIR/loras" \
  "$MODELS_DIR/hunyuanfoley"

if [ -f /venv/main/bin/activate ]; then
  . /venv/main/bin/activate
fi

python -m pip install --no-cache-dir -U "huggingface_hub[cli]"

# ────────────────────────────────────────────────────────────
# Helper: download from HF repo via CLI
# ────────────────────────────────────────────────────────────
download_if_missing() {
  local repo="$1"
  local file="$2"
  local out="$3"

  if [ -f "$out" ]; then
    echo "[OK] exists: $out"
    return 0
  fi

  local tmpdir
  tmpdir=$(mktemp -d)

  hf download "$repo" "$file" --local-dir "$tmpdir"
  mv "$tmpdir/$file" "$out"
  rm -rf "$tmpdir"

  echo "[OK] downloaded: $out"
}

# ────────────────────────────────────────────────────────────
# Helper: download via wget with HF auth
# ────────────────────────────────────────────────────────────
HF_TOKEN="${HF_TOKEN:-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}"

download_hf_wget() {
  local url="$1"
  local out="$2"

  if [ -f "$out" ]; then
    echo "[OK] exists: $out"
    return 0
  fi

  wget -q --show-progress --header="Authorization: Bearer $HF_TOKEN" -O "$out" "$url"
  echo "[OK] downloaded: $out"
}

# ============================================================
# [1/3] Wan 2.2 I2V weights (~40 GB)
# ============================================================
echo "========== [1/3] Wan 2.2 I2V weights =========="

download_if_missing \
  "Comfy-Org/Wan_2.1_ComfyUI_repackaged" \
  "split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
  "$MODELS_DIR/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

download_if_missing \
  "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" \
  "split_files/vae/wan_2.1_vae.safetensors" \
  "$MODELS_DIR/vae/wan_2.1_vae.safetensors"

download_if_missing \
  "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" \
  "split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors" \
  "$MODELS_DIR/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors"

download_if_missing \
  "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" \
  "split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors" \
  "$MODELS_DIR/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors"

download_if_missing \
  "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" \
  "split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors" \
  "$MODELS_DIR/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors"

download_if_missing \
  "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" \
  "split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors" \
  "$MODELS_DIR/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors"

# ============================================================
# [2/3] Flux 2 weights (~20 GB)
# ============================================================
echo "========== [2/3] Flux 2 weights =========="

download_hf_wget \
  "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/text_encoders/mistral_3_small_flux2_bf16.safetensors" \
  "$MODELS_DIR/text_encoders/mistral_3_small_flux2_bf16.safetensors"

download_hf_wget \
  "https://huggingface.co/ByteZSzn/Flux.2-Turbo-ComfyUI/resolve/main/Flux_2-Turbo-LoRA_comfyui.safetensors" \
  "$MODELS_DIR/loras/Flux_2-Turbo-LoRA_comfyui.safetensors"

download_hf_wget \
  "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/diffusion_models/flux2_dev_fp8mixed.safetensors" \
  "$MODELS_DIR/diffusion_models/flux2_dev_fp8mixed.safetensors"

download_hf_wget \
  "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors" \
  "$MODELS_DIR/vae/flux2-vae.safetensors"

# ============================================================
# [3/3] HunyuanFoley weights + custom node (~12 GB)
# ============================================================
echo "========== [3/3] HunyuanFoley (audio) =========="

# --- Models (tencent/HunyuanVideo-Foley) ---

download_if_missing \
  "tencent/HunyuanVideo-Foley" \
  "hunyuanvideo_foley.pth" \
  "$MODELS_DIR/hunyuanfoley/hunyuanvideo_foley.pth"

download_if_missing \
  "tencent/HunyuanVideo-Foley" \
  "vae_128d_48k.pth" \
  "$MODELS_DIR/hunyuanfoley/vae_128d_48k.pth"

download_if_missing \
  "tencent/HunyuanVideo-Foley" \
  "synchformer_state_dict.pth" \
  "$MODELS_DIR/hunyuanfoley/synchformer_state_dict.pth"

download_if_missing \
  "tencent/HunyuanVideo-Foley" \
  "config.yaml" \
  "$MODELS_DIR/hunyuanfoley/config.yaml"

# --- Custom node (martinroot fork) ---

FOLEY_NODE_DIR="${CUSTOM_NODES_DIR}/Comfyui-HunyuanFoley"
if [ -d "$FOLEY_NODE_DIR" ]; then
  echo "[OK] Comfyui-HunyuanFoley already installed, pulling updates..."
  cd "$FOLEY_NODE_DIR" && git pull --ff-only 2>/dev/null || true
  cd "$WORKSPACE_DIR"
else
  echo "[INSTALL] Cloning Comfyui-HunyuanFoley (martinroot fork)..."
  git clone https://github.com/martinroot/Comfyui-HunyuanFoley.git "$FOLEY_NODE_DIR"
fi

# --- Python dependencies ---

echo "[INSTALL] HunyuanFoley pip dependencies..."
pip install --no-cache-dir \
  diffusers \
  timm \
  accelerate \
  transformers \
  sentencepiece \
  "git+https://github.com/descriptinc/audiotools" \
  pillow \
  einops \
  pyyaml \
  omegaconf \
  loguru \
  tqdm

# --- Pre-download HuggingFace models used at runtime ---
# SigLIP2 and CLAP are downloaded on first run by transformers.
# Pre-cache them so cold start is instant.

echo "[CACHE] Pre-downloading SigLIP2 and CLAP models..."
python -c "
from transformers import AutoModel, AutoProcessor, ClapModel, ClapProcessor
print('  Downloading SigLIP2...')
AutoModel.from_pretrained('google/siglip2-base-patch16-512', trust_remote_code=True)
AutoProcessor.from_pretrained('google/siglip2-base-patch16-512', trust_remote_code=True)
print('  Downloading CLAP...')
ClapModel.from_pretrained('laion/larger_clap_general')
ClapProcessor.from_pretrained('laion/larger_clap_general')
print('  [OK] Cached.')
" 2>/dev/null || echo "[WARN] Could not pre-cache HF models, will download on first run"

echo "========== ALL DONE (~72GB) =========="
