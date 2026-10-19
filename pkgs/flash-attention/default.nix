{ upstream, torch }:

# 二进制 Torch 使用默认编译器；CUDA 扩展需要使用 CUDA 工具链支持的编译器。
(upstream.override {
  torch = torch // { stdenv = torch.cudaPackages.backendStdenv; };
}).overridePythonAttrs (old: {
  env = (old.env or { }) // {
    # 禁止 setup.py 在构建时下载预编译轮子，直接针对当前 Torch 编译。
    FLASH_ATTENTION_FORCE_BUILD = "TRUE";
  };
})
