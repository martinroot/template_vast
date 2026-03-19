#!/bin/bash
set -euo pipefail

# ============================================
# Flux 2 img2img + Wan 2.2 I2V — ALL weights
# Template hash: b0eb4a914bfe6083ab77ae93dd969f48
# Total: ~60 GB
# ============================================

WORKSPACE_DIR="${WORKSPACE:-/workspace}"
COMFYUI_DIR="${WORKSPACE_DIR}/ComfyUI"
MODELS_DIR="${COMFYUI_DIR}/models"

mkdir -p \
  "$MODELS_DIR/text_encoders" \
  "$MODELS_DIR/vae" \
  "$MODELS_DIR/diffusion_models" \
  "$MODELS_DIR/loras"

if [ -f /venv/main/bin/activate ]; then
  . /venv/main/bin/activate
fi

python -m pip install --no-cache-dir -U "huggingface_hub[cli]"

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

HF_TOKEN="${HF_TOKEN:-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}"

echo "========== [1/2] Wan 2.2 I2V weights =========="

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

echo "========== [2/2] Flux 2 weights =========="

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

echo "========== ALL DONE (~60GB) =========="
