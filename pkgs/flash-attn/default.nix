{ lib
, buildPythonPackage
, autoPatchelfHook
, torch
, einops
}:
# FlashAttention-2 预编译 wheel 包装。
# wheel 命名约定：cu12torch2.5cxx11abiTRUE-cp312-cp312-linux_x86_64
# 与 research-incubator 当前栈匹配（torch 2.5.x + CUDA 12 + cp312 + cxx11 ABI）。
let
  url = "https://github.com/Dao-AILab/flash-attention/releases/download/v2.7.4.post1/flash_attn-2.7.4.post1+cu12torch2.5cxx11abiTRUE-cp312-cp312-linux_x86_64.whl";
in
buildPythonPackage rec {
  pname = "flash-attn";
  version = "2.7.4.post1";
  format = "wheel";

  src = builtins.fetchurl {
    inherit url;
    sha256 = "sha256-h6kda/WSHKohMinDe9LwfOfwEjHDXDaoEseSmd3b/3Y=";
  };

  # wheel 内含预编译 .so，需要 autoPatchelfHook 修补 RPATH（指向 torch / cuda libs）。
  nativeBuildInputs = [ autoPatchelfHook ];

  propagatedBuildInputs = [
    torch
    einops
  ];

  # wheel 已是二进制产物，无需走 buildPhase；torch 的 ninja setup-hook 否则会触发空 build。
  dontBuild = true;

  # 跳过测试：wheel 内置的测试需要真实 GPU；建议在下游 dev shell 中验证。
  doCheck = false;

  # 跳过 import 自检：standalone build 环境可能缺少 CUDA runtime / 匹配的 torch；
  # 真正的 import 验证放到 research-incubator dev shell（CUDA 12 + torch 2.5）。
  dontUsePythonImportsCheck = true;

  # wheel 含未解析的 CUDA runtime 符号（libcuda.so.1），构建机无 NVIDIA driver lib；
  # 真正的 dlopen 在下游 CUDA-enabled 主机上才会发生。
  autoPatchelfIgnoreMissingDeps = true;

  meta = with lib; {
    description = "FlashAttention-2: fast and memory-efficient exact attention";
    homepage = "https://github.com/Dao-AILab/flash-attention";
    license = licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
}
