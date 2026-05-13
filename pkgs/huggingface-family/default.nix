{ python-final, python-prev, rustOverride ? { } }:

# HuggingFace family packages - ordered by dependency.
#
# rustOverride（可选）：当宿主 nixpkgs 的 rust 工具链不足以编译 hf-xet / tokenizers
# 所需的 edition2024 crate 时（例如 nixpkgs 24.11 自带 cargo 1.82），可通过此参数
# 注入更新的 { rustc, cargo, rustPlatform } —— 只作用于这两个包，避免改动整个 rust
# 集合（防止 polars 等仅需 1.82 的包跟着升级到 1.91 后出现兼容性回退）。
#
# 注意各包接收参数不一致：
#   - hf-xet/default.nix 只接收 rustPlatform；
#   - tokenizers/default.nix 还显式接收 cargo 与 rustc 作为顶层入参。
# 故 callPackage 时按需子集传递，避免触发 "unexpected argument" 报错。

let
  hfXetRust = builtins.intersectAttrs { rustPlatform = null; } rustOverride;
  tokenizersRust = builtins.intersectAttrs {
    rustPlatform = null;
    cargo = null;
    rustc = null;
  } rustOverride;
in
rec {
  hf-xet = python-final.callPackage ./hf-xet hfXetRust;

  huggingface-hub = python-final.callPackage ./huggingface-hub {
    hf-xet = hf-xet;
  };

  tokenizers = python-final.callPackage ./tokenizers (tokenizersRust // {
    huggingface-hub = huggingface-hub;
  });

  transformers = python-final.callPackage ./transformers {
    huggingface-hub = huggingface-hub;
    tokenizers = tokenizers;
  };

  sentence-transformers = python-final.callPackage ./sentence-transformers {
    transformers = transformers;
  };
}
