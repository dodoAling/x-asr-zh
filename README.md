# X-ASR 中文使用指南

基于 icefall/k2、Zipformer transducer 架构的**中英文流式语音识别模型**使用说明。
模型支持**真流式 + 离线**两种解码，通过 **sherpa-onnx** 部署，CPU 即可运行。

- 上游代码仓库：[GitHub - Gilgamesh-J/X-ASR](https://github.com/Gilgamesh-J/X-ASR)（Apache-2.0）

> 本仓库为 X-ASR 的中文二次发行：包含上游全部代码（部署、训练、桌面应用工程），
> **不含模型权重与 demo 视频**（体积太大，按下方说明从模型仓库下载）。

## 仓库结构

| 目录 | 内容 |
|---|---|
| `deploy/` | sherpa-onnx 部署：WebSocket 服务端/客户端（`deploy/src/`）、`deploy/models/` 模型目录（权重需下载） |
| `training/` | icefall 训练代码与词表（`.pt` checkpoint 需下载） |
| `apps/vibe-xasr/` | 桌面语音输入法工程（`macos/`、`windows/`） |
| `site/` | 桌面应用的更新源页面（appcast / 发行说明） |
| `scripts/` | 模型下载脚本 |
| `docs/` | 原始 README 存档（英文/中文） |
| `assets/` | 图片素材 |

## 模型仓库（两个源，内容相同）

| 源 | 地址 | 适用 |
|---|---|---|
| ModelScope（国内镜像） | https://www.modelscope.ai/Gilgamesh-J/X-ASR-zh-en | 国内网络，下载快 |
| HuggingFace（国外） | https://huggingface.co/GilgameshWind/X-ASR-zh-en | 海外网络 |

两个仓库内容一致：4 档 ONNX 权重（`deployment/models/`）、训练用 `.pt` checkpoint（`streaming_exp/`）、部署代码（`deployment/`）、Vibe XASR 桌面应用（`applications/`）。整包约 5.8 GB，按下面"二次开发需要什么"只取所需部分即可。

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
- `streaming_exp/` 下还有 `.pt` checkpoint（~610 MB），仅训练/fine-tune 需要，部署不用下（GitHub 上游对应 `zipformer/checkpoint/`）
- 当前只有 fp32；想压体积可自行用 onnxruntime 做 int8 量化（约 1/4 体积，精度略损）

## 二次开发需要什么

X-ASR 是标准 sherpa-onnx zipformer2 transducer 模型，Apache-2.0 允许商用与再分发（需保留 LICENSE 与版权头）。按目标取文件：

| 目标 | 需要的文件 | 怎么集成 |
|---|---|---|
| **做自己的 App/软件** | 某一档 ONNX 四件套（~600 MB） | sherpa-onnx 官方 SDK：C++ / Python / Java / Kotlin / Swift / C#，有 Windows、macOS、Linux、Android、iOS 预编译库；权重可随 App 打包或首启下载 |
| **自建识别服务** | 某一档 ONNX + `deploy/src/` 三个脚本 | 直接跑 WebSocket 服务端（见下方快速开始），或照协议自己实现服务端 |
| **本机听写/语音输入** | 同上 + VAD 模型 | 流式 ASR 只负责边听边出字，需另接端点检测（如 FireRedVAD）判断一句何时结束 |
| **微调/训练** | `.pt` checkpoint + `training/` 训练代码 | 走 icefall/k2 训练框架，需要 GPU 与语料 |

sherpa-onnx 侧模型类型传 `zipformer2`，运行时参数见快速开始一节；桌面应用可参考上游 Vibe XASR 的打包方式（单档模型 + 本地推理，离线可用）。

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

只要某一档，用 include 过滤（下载后把 `deployment/models/chunk-<N>ms-model/` 移到本仓库 `deploy/models/` 下）：

```powershell
hf download GilgameshWind/X-ASR-zh-en `
  --include "deployment/models/chunk-480ms-model/*" `
  --local-dir ./X-ASR-zh-en
```

### 方式三：本仓库脚本（推荐）

直接落到 `deploy/models/`：

```powershell
# 默认拉 480ms 档，源可选 hf / modelscope
.\scripts\download-models.ps1 -Chunk 480 -Source modelscope
```

## 快速开始（WebSocket 流式）

```powershell
cd deploy
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

启动服务端（以 480 ms 档、CPU 为例）：

```powershell
python src/sherpa_streaming_server.py `
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
python src/sherpa_streaming_client.py `
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

## 许可

- 代码与模型按 [Apache-2.0](LICENSE) 发布：允许商用、修改与再分发
- 再分发时需保留 LICENSE 及各源文件内的版权声明；模型权重与媒体文件不包含在本仓库内
