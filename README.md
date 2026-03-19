# Vast.ai Template Scripts

Provisioning scripts for ComfyUI templates on vast.ai.

## Templates

### 1. Wan 2.2 I2V (`wan22_i2v.sh`)
- **Hash:** `e82521203035e2c8bd124820eeb49f83`
- **Weights:** ~36 GB (6 files)
- **Disk:** 60 GB min

### 2. Flux 2 + Wan 2.2 I2V (`flux2_wan22_i2v.sh`)
- **Hash:** `b0eb4a914bfe6083ab77ae93dd969f48`
- **Weights:** ~60 GB (10 files)
- **Disk:** 100 GB min

## Vast.ai Launch Strings

### Wan 2.2 I2V (hash: e82521203035e2c8bd124820eeb49f83)
```
-p 1111:1111 -p 8080:8080 -p 8384:8384 -p 72299:72299 -p 8188:8188 -p 8288:8288 -e COMFYUI_ARGS="--disable-auto-launch --disable-xformers --port 18188 --enable-cors-header" -e COMFYUI_API_BASE=http://localhost:18188 -e PROVISIONING_SCRIPT=https://raw.githubusercontent.com/martinroot/template_vast/main/wan22_i2v.sh -e PORTAL_CONFIG="localhost:1111:11111:/:Instance Portal|localhost:8188:18188:/:ComfyUI|localhost:8288:18288:/docs:API Wrapper|localhost:8080:18080:/:Jupyter|localhost:8080:8080:/terminals/1:Jupyter Terminal|localhost:8384:18384:/:Syncthing" -e OPEN_BUTTON_PORT=1111 -e JUPYTER_DIR=/ -e DATA_DIRECTORY=/workspace/ -e OPEN_BUTTON_TOKEN=1
```

### Flux 2 + Wan 2.2 I2V (hash: b0eb4a914bfe6083ab77ae93dd969f48)
```
-p 1111:1111 -p 8080:8080 -p 8384:8384 -p 72299:72299 -p 8188:8188 -p 8288:8288 -e COMFYUI_ARGS="--disable-auto-launch --disable-xformers --port 18188 --enable-cors-header" -e COMFYUI_API_BASE=http://localhost:18188 -e PROVISIONING_SCRIPT=https://raw.githubusercontent.com/martinroot/template_vast/main/flux2_wan22_i2v.sh -e PORTAL_CONFIG="localhost:1111:11111:/:Instance Portal|localhost:8188:18188:/:ComfyUI|localhost:8288:18288:/docs:API Wrapper|localhost:8080:18080:/:Jupyter|localhost:8080:8080:/terminals/1:Jupyter Terminal|localhost:8384:18384:/:Syncthing" -e OPEN_BUTTON_PORT=1111 -e JUPYTER_DIR=/ -e DATA_DIRECTORY=/workspace/ -e OPEN_BUTTON_TOKEN=1
```
