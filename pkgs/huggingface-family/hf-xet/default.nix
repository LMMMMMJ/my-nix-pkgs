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
  version = "1.7.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "huggingface";
    repo = "xet-core";
    tag = "v${version}";
    hash = "sha256-7j4vClUaEKri3Uu8hv8IEqJCDar0xR8RBxPJbP1sZFg=";
  };

  sourceRoot = "${src.name}/hf_xet";

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit
      pname
      version
      src
      sourceRoot
      ;
    hash = "sha256-+4n7begwEeRzUpROad/2u15CfRgqBXzp3wGUztUuzSE=";
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

  meta = {
    description = "Xet client tech, used in huggingface_hub";
    homepage = "https://github.com/huggingface/xet-core/tree/main/hf_xet";
    changelog = "https://github.com/huggingface/xet-core/releases/tag/v${version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ GaetanLepage ];
  };
}
