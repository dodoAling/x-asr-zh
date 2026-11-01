# Model Files

Model weights are not committed to this repository (each chunk variant is ~586 MB).
Download them into this directory before running the server.

Easiest way (from the repo root):

```powershell
.\scripts\download-models.ps1 -Chunk 480 -Source modelscope
```

Equivalent manual commands (download elsewhere, then move `chunk-<N>ms-model/` here):

```powershell
# ModelScope
modelscope download --model Gilgamesh-J/X-ASR-zh-en --include "deployment/models/chunk-480ms-model/*" --local_dir ./dl
# HuggingFace
hf download GilgameshWind/X-ASR-zh-en --include "deployment/models/chunk-480ms-model/*" --local-dir ./dl
```

Expected layout:

```text
models/
├── chunk-160ms-model/
│   ├── encoder-160ms.onnx
│   ├── decoder-160ms.onnx
│   ├── joiner-160ms.onnx
│   └── tokens.txt
├── chunk-480ms-model/
├── chunk-960ms-model/
└── chunk-1920ms-model/
```

`tokens.txt` files are committed; the `.onnx` files are the parts you download.
