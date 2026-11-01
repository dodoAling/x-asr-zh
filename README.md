# X-ASR 中文使用指南

基于 icefall/k2、Zipformer transducer 架构的**中英文流式语音识别模型**使用说明。
模型支持**真流式 + 离线**两种解码，通过 **sherpa-onnx** 部署，CPU 即可运行。

- 模型仓库（下载权重用）：[HuggingFace](https://huggingface.co/GilgameshWind/X-ASR-zh-en) · [ModelScope](https://www.modelscope.ai/Gilgamesh-J/X-ASR-zh-en)
- 上游代码仓库：[GitHub - Gilgamesh-J/X-ASR](https://github.com/Gilgamesh-J/X-ASR)（Apache-2.0）
- 在线体验：[stream-asr.sjtuxlance.com](https://stream-asr.sjtuxlance.com/) · [HF Space](https://huggingface.co/spaces/chenxie95/X-ASR)

> 本仓库只是使用文档，不含模型权重与上游代码。

## 模型规格

| 项目 | 说明 |
|---|---|
| 语言 | 中文、英文（混说可切换） |
| 架构 | Zipformer transducer，约 0.16B 参数 |
| 训练数据 | 约 100 万小时开源及收集语音 |
| 输出 | 带标点、英文带大小写 |
| 权重格式 | ONNX（fp32，部署用）+ PyTorch checkpoint（训练/fine-tune 用） |
| 运行时 | sherpa-onnx（CPU / CUDA / 各平台） |

## 流式档位（chunk size）

同一个模型按不同 chunk 大小导出了 4 份流式权重。**chunk 越小延迟越低、精度略降**；离线模式精度最高但不算流式。

| 档位 | 每步延迟量级 | 适用场景 |
|---|---|---|
| 160 ms | 极低 | 实时字幕、语音输入法、打断交互 |
| 480 ms | 低 | 通用流式甜点档，延迟/精度均衡 |
| 960 ms | 中 | 会议记录、字幕生成 |
| 1920 ms | 较高 | 对延迟不敏感、追求接近离线的精度 |
| 离线 | 整段 | 转写文件，精度最高 |

Benchmark（greedy search，WER/CER %，越低越好）：

| 模式 | Chunk | LibriSpeech clean | LibriSpeech other | GigaSpeech | WenetSpeech net | WenetSpeech meeting |
|---|---|---|---|---|---|---|
| 流式 | 160 ms | 3.49 | 8.75 | 10.32 | 8.72 | 10.47 |
| 流式 | 480 ms | 2.99 | 7.36 | 9.70 | 7.46 | 9.11 |
| 流式 | 960 ms | 2.87 | 6.77 | 9.59 | 6.97 | 8.40 |
| 流式 | 1920 ms | 2.75 | 6.33 | 9.43 | 6.58 | 7.88 |
| 离线 | — | **2.56** | **5.56** | **9.17** | **5.83** | **7.06** |

## 权重清单

每档一个目录，四个文件必须来自同一目录、配套使用：

```
chunk-<N>ms-model/
├── encoder-<N>ms.onnx   ~565 MB   # Zipformer encoder，参数的绝大部分
├── decoder-<N>ms.onnx   ~11 MB
├── joiner-<N>ms.onnx    ~10 MB
└── tokens.txt           ~100 KB   # 词表
```

- 四档全下 ≈ 2.3 GB；只跑一档选一份即可（推荐先试 480 ms 或 160 ms）
- 另有两个 `.pt` checkpoint（各 ~610 MB）：`pretrained.pt` 与 `fintuned_with_punctuation.pt`，仅训练/fine-tune 需要，部署不用下
- 当前只有 fp32；想压体积可自行用 onnxruntime 做 int8 量化（约 1/4 体积，精度略损）

## 下载模型

### 方式一：ModelScope（国内推荐）

```powershell
pip install modelscope
modelscope download --model Gilgamesh-J/X-ASR-zh-en --local_dir ./X-ASR-zh-en
```

### 方式二：HuggingFace

```powershell
pip install huggingface_hub[hf_transfer]
hf download GilgameshWind/X-ASR-zh-en --local-dir ./X-ASR-zh-en
```

只要某一档，用 include 过滤：

```powershell
hf download GilgameshWind/X-ASR-zh-en `
  --include "deployment/models/chunk-480ms-model/*" `
  --local-dir ./X-ASR-zh-en
```

### 方式三：本仓库脚本

```powershell
# 默认拉 480ms 档，源可选 hf / modelscope
.\scripts\download-models.ps1 -Chunk 480 -Source modelscope
```

## 快速开始（WebSocket 流式）

部署代码在上游仓库的 `X-ASR-zh-en/deployment/` 下，HF/ModelScope 的模型包里也带 `deployment/` 目录。

```powershell
cd X-ASR-zh-en/deployment
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

启动服务端（以 480 ms 档、CPU 为例）：

```powershell
python infer_and_client/sherpa_streaming_server.py `
  --host 0.0.0.0 --port 6666 `
  --tokens models/chunk-480ms-model/tokens.txt `
  --encoder models/chunk-480ms-model/encoder-480ms.onnx `
  --decoder models/chunk-480ms-model/decoder-480ms.onnx `
  --joiner models/chunk-480ms-model/joiner-480ms.onnx `
  --provider cpu --sample-rate 16000 --feature-dim 80 `
  --num-threads 4 --decoding-method greedy_search `
  --model-type zipformer2 --enable-endpoint-detection 0 --text-format none
```

另开终端跑客户端（把 WAV 按实时速度推流）：

```powershell
python infer_and_client/sherpa_streaming_client.py `
  --server-uri ws://127.0.0.1:6666 `
  --wav .\test.wav --chunk-ms 100 --simulate-realtime 1
```

### WebSocket 协议

| 步骤 | 消息 | 作用 |
|---|---|---|
| 1 | JSON `{"type":"start","sample_rate":16000}` | 开启一次识别会话 |
| 2 | 二进制 int16 PCM 块 | 持续推流（16 kHz 单声道） |
| 3 | JSON `{"type":"end"}` | 结束会话，返回 final 结果 |

每个连接独立 session，服务端支持多客户端并发。可选 `--enable-energy-tail-probe 1` 让停顿后的尾部 partial 刷新更及时（适合语音输入法类交互）。

## 衍生玩法

- **本机听写/VAD 联动**：上游 `x-asr-live-demo` 用 FireRedVAD 做端点检测 + X-ASR 流式解码，可改成"说完一句自动上屏"的离线语音输入
- **Vibe XASR**：上游同作者的桌面语音输入法（macOS / Windows 预览版），发布在 [GitHub Releases](https://github.com/Gilgamesh-J/X-ASR/releases)

## 说明

- 模型权重与部署代码版权归上游所有，[Apache-2.0](https://github.com/Gilgamesh-J/X-ASR/blob/main/LICENSE)，商用允许
- 本仓库仅维护中文使用文档，与上游无官方关系；模型问题请去 [上游 Issues](https://github.com/Gilgamesh-J/X-ASR/issues)
