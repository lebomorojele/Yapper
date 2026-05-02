# Local Inference Assets

Bundled with the app:

- `llama-cli`: llama.cpp b8868 macOS arm64 CLI executable
- `llama-completion`: llama.cpp b8868 macOS arm64 completion executable used by the app

Downloaded on opt-in:

- `cleanup-model.gguf`: Qwen2.5 1.5B Instruct Q4_K_M GGUF from `Qwen/Qwen2.5-1.5B-Instruct-GGUF`
- Source URL: `https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf`
- Install location: `~/Library/Application Support/Yapper/LocalInference/cleanup-model.gguf`

Verification hashes:

- `cleanup-model.gguf`: `6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e`
- `llama-cli`: `191f0c32ff90cc584c71c01bf2e7a5eb4eec98e7bb83dd9570c4efea9a95035c`
- `llama-completion`: `6f936e26858c690b46ed693d0c1ff9c5bdb1ae091cd2a469d9a1e1e556c5d5ab`

Yapper falls back to deterministic local cleanup when the model is missing, declined, downloading, or fails at runtime.
