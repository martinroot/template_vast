#!/bin/bash
set -e

# ═══════════════════════════════════════════════════════
# GPU Portal — Provisioning Script
# Flux 2 + Wan 2.2 I2V with Audio (built-in, no Foley)
# ComfyUI native WanImageToVideoAudio node
# Total ~55GB weights
# ═══════════════════════════════════════════════════════

COMFY_DIR="${WORKSPACE:-/workspace}/ComfyUI"
HF_TOKEN="${HF_TOKEN:-}"
PORTAL_URL="${PORTAL_URL:-}"

echo "╔═══════════════════════════════════════╗"
echo "║  Flux 2 + Wan 2.2 I2V + Audio Setup  ║"
echo "║  Total ~55GB weights to download      ║"
echo "╚═══════════════════════════════════════╝"

# Notify portal
notify() {
    local step=$1 detail=$2
    echo "[$(date +%H:%M:%S)] $step: $detail"
    if [ -n "$PORTAL_URL" ]; then
        curl -s -X POST "$PORTAL_URL/api/provision/log" \
            -H "Content-Type: application/json" \
            -d "{\"instance_id\":\"C.$(hostname)\",\"step\":\"$step\",\"detail\":\"$detail\"}" 2>/dev/null || true
    fi
}

notify "provision_start" "Boot started, ~55GB to download"

# Upgrade huggingface_hub
notify "pip_hf_upgrade" "upgrading huggingface_hub[cli]"
pip install -q --upgrade huggingface_hub[cli] 2>/dev/null
notify "pip_hf_upgrade_done" ""

# ──────────── [1/3] Wan 2.2 I2V weights (~28GB FP8) ────────────
notify "section_start" "[1/3] Wan 2.2 I2V + Audio weights (~29GB)"

cd "$COMFY_DIR"

# VAE
notify "download_start" "wan2.1_vae.safetensors from Comfy-Org/Wan_2.2_ComfyUI_Repackaged"
huggingface-cli download Comfy-Org/Wan_2.2_ComfyUI_Repackaged --include "split_files/vae/*" --local-dir models/
ln -sf "$COMFY_DIR/models/split_files/vae/wan2.1_vae.safetensors" models/vae/wan2.1_vae.safetensors 2>/dev/null || true
notify "download_done" "wan2.1_vae.safetensors"

# Text encoder
notify "download_start" "umt5_xxl_fp8 from Comfy-Org/Wan_2.1_ComfyUI_repackaged"
huggingface-cli download Comfy-Org/Wan_2.1_ComfyUI_repackaged --include "split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" --local-dir models/
ln -sf "$COMFY_DIR/models/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors 2>/dev/null || true
notify "download_done" "umt5_xxl_fp8"

# I2V models (FP8 for memory efficiency)
for model in wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors; do
    notify "download_start" "$model from Comfy-Org/Wan_2.2_ComfyUI_Repackaged"
    huggingface-cli download Comfy-Org/Wan_2.2_ComfyUI_Repackaged --include "split_files/diffusion_models/$model" --local-dir models/
    ln -sf "$COMFY_DIR/models/split_files/diffusion_models/$model" "models/diffusion_models/$model" 2>/dev/null || true
    notify "download_done" "$model"
done

# LightX2V LoRAs (4-step acceleration)
for lora in wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors; do
    notify "download_start" "$lora from Comfy-Org/Wan_2.2_ComfyUI_Repackaged"
    huggingface-cli download Comfy-Org/Wan_2.2_ComfyUI_Repackaged --include "split_files/loras/$lora" --local-dir models/
    ln -sf "$COMFY_DIR/models/split_files/loras/$lora" "models/loras/$lora" 2>/dev/null || true
    notify "download_done" "$lora"
done

# Audio encoder (wav2vec2) — ~600MB
notify "download_start" "wav2vec2_large_english_fp16 from Comfy-Org/Wan_2.2_ComfyUI_Repackaged"
huggingface-cli download Comfy-Org/Wan_2.2_ComfyUI_Repackaged --include "split_files/audio_encoders/wav2vec2_large_english_fp16.safetensors" --local-dir models/
mkdir -p models/audio_encoders 2>/dev/null || true
ln -sf "$COMFY_DIR/models/split_files/audio_encoders/wav2vec2_large_english_fp16.safetensors" models/audio_encoders/wav2vec2_large_english_fp16.safetensors 2>/dev/null || true
notify "download_done" "wav2vec2_large_english_fp16"

notify "section_done" "[1/3] Wan 2.2 I2V + Audio done"

# ──────────── [2/3] Flux 2 weights (~70GB) ────────────
notify "section_start" "[2/3] Flux 2 weights (~70GB) via hf download"

# Flux 2 text encoder (Mistral)
notify "download_start" "mistral_3_small_flux2_bf16.safetensors from Comfy-Org/flux2-dev"
huggingface-cli download Comfy-Org/flux2-dev --include "split_files/text_encoders/mistral_3_small_flux2_bf16.safetensors" --local-dir models/
ln -sf "$COMFY_DIR/models/split_files/text_encoders/mistral_3_small_flux2_bf16.safetensors" models/text_encoders/mistral_3_small_flux2_bf16.safetensors 2>/dev/null || true
notify "download_done" "mistral_3_small_flux2_bf16.safetensors"

# Flux 2 Turbo LoRA
notify "download_start" "Flux_2-Turbo-LoRA_comfyui.safetensors from ByteZSzn/Flux.2-Turbo-ComfyUI"
huggingface-cli download ByteZSzn/Flux.2-Turbo-ComfyUI Flux_2-Turbo-LoRA_comfyui.safetensors --local-dir models/loras/
notify "download_done" "Flux_2-Turbo-LoRA_comfyui.safetensors"

# Flux 2 Dev FP8
notify "download_start" "flux2_dev_fp8mixed.safetensors from Comfy-Org/flux2-dev"
huggingface-cli download Comfy-Org/flux2-dev --include "split_files/diffusion_models/flux2_dev_fp8mixed.safetensors" --local-dir models/
ln -sf "$COMFY_DIR/models/split_files/diffusion_models/flux2_dev_fp8mixed.safetensors" models/diffusion_models/flux2_dev_fp8mixed.safetensors 2>/dev/null || true
notify "download_done" "flux2_dev_fp8mixed.safetensors"

# Flux 2 VAE
notify "download_start" "flux2-vae.safetensors from Comfy-Org/flux2-dev"
huggingface-cli download Comfy-Org/flux2-dev --include "split_files/vae/flux2-vae.safetensors" --local-dir models/
ln -sf "$COMFY_DIR/models/split_files/vae/flux2-vae.safetensors" models/vae/flux2-vae.safetensors 2>/dev/null || true
notify "download_done" "flux2-vae.safetensors"

notify "section_done" "[2/3] Flux 2 done"

# ──────────── [3/3] Done ────────────
notify "section_start" "[3/3] Finalization"
notify "section_done" "[3/3] Done — no Foley stack needed (Wan native audio)"

notify "provision_complete" "ALL DONE (~55GB) — Flux 2 + Wan 2.2 I2V + Audio"
