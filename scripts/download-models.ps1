<#
.SYNOPSIS
    下载 X-ASR-zh-en 指定流式档位的 ONNX 权重。

.PARAMETER Chunk
    流式档位：160 / 480 / 960 / 1920（毫秒）。默认 480。

.PARAMETER Source
    下载源：hf（HuggingFace）或 modelscope。默认 modelscope（国内较快）。

.PARAMETER OutDir
    输出根目录，默认 ./X-ASR-zh-en。

.EXAMPLE
    .\download-models.ps1 -Chunk 480 -Source modelscope
#>
param(
    [ValidateSet(160, 480, 960, 1920)]
    [int]$Chunk = 480,

    [ValidateSet("hf", "modelscope")]
    [string]$Source = "modelscope",

    [string]$OutDir = "./X-ASR-zh-en"
)

$ErrorActionPreference = "Stop"
$pattern = "deployment/models/chunk-${Chunk}ms-model/*"

if ($Source -eq "modelscope") {
    if (-not (Get-Command modelscope -ErrorAction SilentlyContinue)) {
        pip install modelscope
    }
    modelscope download --model Gilgamesh-J/X-ASR-zh-en `
        --include $pattern `
        --local_dir $OutDir
} else {
    if (-not (Get-Command hf -ErrorAction SilentlyContinue)) {
        pip install "huggingface_hub[hf_transfer]"
    }
    hf download GilgameshWind/X-ASR-zh-en `
        --include $pattern `
        --local-dir $OutDir
}

$dir = Join-Path $OutDir "deployment/models/chunk-${Chunk}ms-model"
if (Test-Path $dir) {
    Write-Host "已下载到 $dir"
    Get-ChildItem $dir | Format-Table Name, @{n = "MB"; e = { [math]::Round($_.Length / 1MB, 1) } }
}
