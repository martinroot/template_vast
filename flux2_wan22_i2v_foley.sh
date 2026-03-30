#!/bin/bash
set -euo pipefail

# ============================================================
# Flux 2 img2img + Wan 2.2 I2V + HunyuanFoley — ALL weights
# Template hash: e6c5ad164d71fe4740db66fa7eccd48e
# Total: ~80-90 GB
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

# ────────────────────────────────────────────────────────────
# Provision timing reporter — sends checkpoints to portal
# ────────────────────────────────────────────────────────────
T0=$(date +%s)
INSTANCE_ID="${VAST_CONTAINERLABEL:-unknown}"
PORTAL_URL="${PORTAL_URL:-}"

log_step() {
  local step="$1"
  local detail="${2:-}"
  local elapsed=$(( $(date +%s) - T0 ))
  echo ">>> [+${elapsed}s] ${step}: ${detail}"
  if [ -n "$PORTAL_URL" ]; then
    curl -sf --max-time 5 -X POST "${PORTAL_URL}/api/provision/log" \
      -H "Content-Type: application/json" \
      -d "{\"instance_id\":\"${INSTANCE_ID}\",\"step\":\"${step}\",\"elapsed_sec\":${elapsed},\"detail\":\"${detail}\"}" \
      2>/dev/null || true
  fi
}

log_step "provision_start" "Boot started, total ~80-90GB to download"

# ────────────────────────────────────────────────────────────
# Helper: download from HF repo via CLI
# ────────────────────────────────────────────────────────────
download_if_missing() {
  local repo="$1"
  local file="$2"
  local out="$3"

  if [ -f "$out" ]; then
    echo "[OK] exists: $out"
    log_step "skip" "$(basename $out) already on disk"
    return 0
  fi

  log_step "download_start" "$(basename $out) from $repo"
  local t1=$(date +%s)

  local tmpdir
  tmpdir=$(mktemp -d)

  hf download "$repo" "$file" --local-dir "$tmpdir"
  mv "$tmpdir/$file" "$out"
  rm -rf "$tmpdir"

  local dt=$(( $(date +%s) - t1 ))
  local size_mb=$(du -m "$out" 2>/dev/null | cut -f1 || echo "?")
  log_step "download_done" "$(basename $out) — ${size_mb}MB in ${dt}s"
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
    log_step "skip" "$(basename $out) already on disk"
    return 0
  fi

  local fname=$(basename "$out")
  log_step "download_start" "${fname} via wget"
  local t1=$(date +%s)

  wget -q --show-progress --header="Authorization: Bearer $HF_TOKEN" -O "$out" "$url"

  local dt=$(( $(date +%s) - t1 ))
  local size_mb=$(du -m "$out" 2>/dev/null | cut -f1 || echo "?")
  log_step "download_done" "${fname} — ${size_mb}MB in ${dt}s"
}

# ────────────────────────────────────────────────────────────
# pip upgrade huggingface_hub
# ────────────────────────────────────────────────────────────
log_step "pip_hf_upgrade" "upgrading huggingface_hub[cli]"
python -m pip install --no-cache-dir -U "huggingface_hub[cli]"
log_step "pip_hf_upgrade_done" ""

# ============================================================
# [1/3] Wan 2.2 I2V weights (~40 GB)
# ============================================================
log_step "section_start" "[1/3] Wan 2.2 I2V weights (~40GB)"

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

log_step "section_done" "[1/3] Wan 2.2 done"

# ============================================================
# [2/3] Flux 2 weights (~70 GB) — via hf download (CDN fast, ~1GB/s)
# Previously used wget which was 5x slower (~200 MB/s vs ~1000 MB/s)
# ============================================================
log_step "section_start" "[2/3] Flux 2 weights (~70GB) via hf download"

download_if_missing \
  "Comfy-Org/flux2-dev" \
  "split_files/text_encoders/mistral_3_small_flux2_bf16.safetensors" \
  "$MODELS_DIR/text_encoders/mistral_3_small_flux2_bf16.safetensors"

download_if_missing \
  "ByteZSzn/Flux.2-Turbo-ComfyUI" \
  "Flux_2-Turbo-LoRA_comfyui.safetensors" \
  "$MODELS_DIR/loras/Flux_2-Turbo-LoRA_comfyui.safetensors"

download_if_missing \
  "Comfy-Org/flux2-dev" \
  "split_files/diffusion_models/flux2_dev_fp8mixed.safetensors" \
  "$MODELS_DIR/diffusion_models/flux2_dev_fp8mixed.safetensors"

download_if_missing \
  "Comfy-Org/flux2-dev" \
  "split_files/vae/flux2-vae.safetensors" \
  "$MODELS_DIR/vae/flux2-vae.safetensors"

log_step "section_done" "[2/3] Flux 2 done"

# ============================================================
# [3/3] HunyuanFoley weights + custom node (~12-20 GB)
# ============================================================
log_step "section_start" "[3/3] HunyuanFoley models + custom node"

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

log_step "foley_models_done" "HunyuanFoley model files downloaded"

# --- Custom node ---
FOLEY_NODE_DIR="${CUSTOM_NODES_DIR}/Comfyui-HunyuanFoley"
log_step "custom_node_start" "Cloning/updating Comfyui-HunyuanFoley"
if [ -d "$FOLEY_NODE_DIR" ]; then
  cd "$FOLEY_NODE_DIR" && git pull --ff-only 2>/dev/null || true
  cd "$WORKSPACE_DIR"
else
  git clone https://github.com/martinroot/Comfyui-HunyuanFoley.git "$FOLEY_NODE_DIR"
fi
log_step "custom_node_done" "Comfyui-HunyuanFoley installed"

# --- Python dependencies ---
log_step "pip_foley_start" "pip install HunyuanFoley dependencies (incl. git+audiotools)"
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
log_step "pip_foley_done" "pip install complete"

# --- Pre-download HuggingFace models used at runtime ---
log_step "hf_cache_start" "Pre-downloading SigLIP2 and CLAP via transformers"
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
log_step "hf_cache_done" "SigLIP2 + CLAP cached"

log_step "section_done" "[3/3] HunyuanFoley done"

TOTAL=$(( $(date +%s) - T0 ))
log_step "provision_complete" "ALL DONE in ${TOTAL}s (~80-90GB)"
echo "========== ALL DONE in ${TOTAL}s =========="
