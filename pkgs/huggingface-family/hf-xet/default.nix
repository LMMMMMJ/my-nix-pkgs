{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  pkg-config,
  rustPlatform,
  openssl,
}:

buildPythonPackage rec {
  pname = "hf-xet";
  version = "1.5.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "huggingface";
    repo = "xet-core";
    tag = version;
    hash = "sha256-W48PKYVDpfPzT7wM8W2tQmz01BcM1v6rpENuwUvy4Sw=";
  };

  sourceRoot = "${src.name}/hf_xet";

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit
      pname
      version
      src
      sourceRoot
      ;
    hash = "sha256-agZMRkUdPGX4A9K6em9XHABhAp5aPLaxqYMuTsE10GA=";
  };

  nativeBuildInputs = [
    pkg-config
    rustPlatform.cargoSetupHook
    rustPlatform.maturinBuildHook
  ];

  buildInputs = [
    openssl
  ];

  env.OPENSSL_NO_VENDOR = 1;

  pythonImportsCheck = [ "hf_xet" ];

  # No tests (yet?)
  doCheck = false;

  # 当注入 25.11 的 rust + maturin 时，产出的 wheel 包含 Metadata-Version: 2.4 字段，
  # 而 nixpkgs 24.11 的 packaging 24.1 仅支持到 2.3 —— pythonRuntimeDepsCheckHook
  # 解析失败但 wheel 实际可用。在 24.11 兼容场景下关闭该 hook 检查即可。
  dontCheckRuntimeDeps = true;

  meta = {
    description = "Xet client tech, used in huggingface_hub";
    homepage = "https://github.com/huggingface/xet-core/tree/main/hf_xet";
    changelog = "https://github.com/huggingface/xet-core/releases/tag/${version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ GaetanLepage ];
  };
}
