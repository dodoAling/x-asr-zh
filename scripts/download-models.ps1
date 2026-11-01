<#
.SYNOPSIS
    下载 X-ASR-zh-en 指定流式档位的 ONNX 权重到 deploy/models/。

.PARAMETER Chunk
    流式档位：160 / 480 / 960 / 1920（毫秒）。默认 480。

.PARAMETER Source
    下载源：hf（HuggingFace）或 modelscope。默认 modelscope（国内较快）。

.EXAMPLE
    .\download-models.ps1 -Chunk 480 -Source modelscope
#>
param(
    [ValidateSet(160, 480, 960, 1920)]
    [int]$Chunk = 480,

    [ValidateSet("hf", "modelscope")]
    [string]$Source = "modelscope",

    [string]$ModelsDir = "$PSScriptRoot\..\deploy\models"
)

$ErrorActionPreference = "Stop"
$ModelsDir = (Resolve-Path $ModelsDir).Path
$stage = Join-Path $env:TEMP "xasr-dl-$Chunk"
$pattern = "deployment/models/chunk-${Chunk}ms-model/*"

Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue

if ($Source -eq "modelscope") {
    if (-not (Get-Command modelscope -ErrorAction SilentlyContinue)) {
        pip install modelscope
    }
    modelscope download --model Gilgamesh-J/X-ASR-zh-en `
        --include $pattern `
        --local_dir $stage
} else {
    if (-not (Get-Command hf -ErrorAction SilentlyContinue)) {
        pip install "huggingface_hub[hf_transfer]"
    }
    hf download GilgameshWind/X-ASR-zh-en `
        --include $pattern `
        --local-dir $stage
}

$src = Join-Path $stage "deployment\models\chunk-${Chunk}ms-model"
if (-not (Test-Path $src)) {
    throw "下载完成但未找到 $src，请检查下载输出"
}

$dst = Join-Path $ModelsDir "chunk-${Chunk}ms-model"
New-Item -ItemType Directory -Force $ModelsDir | Out-Null
Copy-Item -Recurse -Force $src $ModelsDir
Remove-Item -Recurse -Force $stage

Write-Host "已下载到 $dst"
Get-ChildItem $dst | Format-Table Name, @{n = "MB"; e = { [math]::Round($_.Length / 1MB, 1) } }
