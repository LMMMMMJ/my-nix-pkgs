{
  lib,
  buildPythonPackage,
  fetchFromGitHub,

  # build-system
  setuptools,

  # dependencies
  filelock,
  fsspec,
  httpx,
  packaging,
  pyyaml,
  shellingham,
  tqdm,
  typer-slim,
  typing-extensions,

  # optional-dependencies
  # oauth
  authlib,
  fastapi,
  itsdangerous,
  # torch
  torch,
  safetensors,
  # hf_transfer
  hf-transfer,
  # fastai
  toml,
  fastai,
  fastcore,
  # hf-xet
  hf-xet,
}:

buildPythonPackage rec {
  pname = "huggingface-hub";
  version = "1.3.3";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "huggingface";
    repo = "huggingface_hub";
    tag = "v${version}";
    hash = "sha256-okQ5ZhSb3NcFH68pyhFVYEpphXrc/DHqIFUggjB8tMY=";
  };

  build-system = [ setuptools ];

  dependencies = [
    filelock
    fsspec
    hf-xet
    httpx
    packaging
    pyyaml
    shellingham
    tqdm
    typer-slim
    typing-extensions
  ];

  optional-dependencies = {
    oauth = [
      authlib
      fastapi
      httpx
      itsdangerous
    ];
    torch = [
      torch
      safetensors
    ]
    ++ safetensors.optional-dependencies.torch or [];
    hf_transfer = [
      hf-transfer
    ];
    fastai = [
      toml
      fastai
      fastcore
    ];
    hf_xet = [
      hf-xet
    ];
  };

  # Tests require network access.
  doCheck = false;

  pythonImportsCheck = [ "huggingface_hub" ];

  meta = {
    description = "Download and publish models and other files on the huggingface.co hub";
    mainProgram = "hf";
    homepage = "https://github.com/huggingface/huggingface_hub";
    changelog = "https://github.com/huggingface/huggingface_hub/releases/tag/v${version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ GaetanLepage ];
  };
}
