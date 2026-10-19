{ upstream, rustPlatform }:

# 当前 nixpkgs 已提供 1.34.0；标准 Maturin hook 会带入 Cargo、rustc 和 maturin。
upstream.overridePythonAttrs (_: {
  build-system = [ ];
  nativeBuildInputs = [
    rustPlatform.cargoSetupHook
    rustPlatform.maturinBuildHook
  ];
  # 新版 SDK 已支持当前的 Protobuf 7，无需放宽版本限制。
  pythonRelaxDeps = [ ];
})
