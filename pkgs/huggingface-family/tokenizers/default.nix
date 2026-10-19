{
  lib,
  buildPythonPackage,
  fetchFromGitHub,

  # nativeBuildInputs
  pkg-config,
  rustPlatform,

  # buildInputs
  openssl,

  # dependencies
  huggingface-hub,

}:

buildPythonPackage rec {
  pname = "tokenizers";
  version = "0.23.3";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "huggingface";
    repo = "tokenizers";
    tag = "v${version}";
    hash = "sha256-vpEkYbELFqS1Jt3q0AxCAkmMO5uiCwkYS0ugicQz7Bc=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit
      pname
      version
      src
      sourceRoot
      ;
    hash = "sha256-LODG+UHDXT5KeJpzytD+tZx5SHydfE8KqzEtwL0iy/o=";
  };

  sourceRoot = "${src.name}/bindings/python";

  nativeBuildInputs = [
    pkg-config
    rustPlatform.cargoSetupHook
    rustPlatform.maturinBuildHook
  ];

  buildInputs = [
    openssl
  ];

  dependencies = [
    huggingface-hub
  ];

  # 上游测试需要访问网络和下载模型数据。
  doCheck = false;

  pythonImportsCheck = [ "tokenizers" ];

  meta = {
    description = "Fast State-of-the-Art Tokenizers optimized for Research and Production";
    homepage = "https://github.com/huggingface/tokenizers";
    changelog = "https://github.com/huggingface/tokenizers/releases/tag/v${version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ GaetanLepage ];
    platforms = lib.platforms.unix;
  };
}
