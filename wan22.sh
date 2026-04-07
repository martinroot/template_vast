#!/bin/bash
set -euo pipefail

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

export HF_TOKEN="${HF_TOKEN:-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}"
python -m pip install --no-cache-dir -U "huggingface_hub[cli]"

download_if_missing() {
  local repo="$1"
  local file="$2"
  local out="$3"

  if [ -f "$out" ]; then
    echo "[OK] exists: $out"
    return 0
  fi

  tmpdir=$(mktemp -d)
  hf download "$repo" "$file" --local-dir "$tmpdir" --token "$HF_TOKEN"
  mv "$tmpdir/$file" "$out"
  rm -rf "$tmpdir"
  echo "[OK] downloaded: $out"
}

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
  "split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors" \
  "$MODELS_DIR/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"

download_if_missing \
  "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" \
  "split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" \
  "$MODELS_DIR/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors"

download_if_missing \
  "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" \
  "split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors" \
  "$MODELS_DIR/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors"

download_if_missing \
  "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" \
  "split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors" \
  "$MODELS_DIR/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors"

echo "Wan 2.2 ready"