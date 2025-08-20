{
  lib,
  buildPythonPackage,
  fetchFromGitHub,

  # build-system
  setuptools,

  # dependencies
  accelerate,
  datasets,
  huggingface-hub,
  optimum,
  pillow,
  scikit-learn,
  scipy,
  torch,
  tqdm,
  transformers,
  typing-extensions,

  # tests
  pytestCheckHook,
  pytest-cov-stub,
}:

buildPythonPackage rec {
  pname = "sentence-transformers";
  version = "5.1.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "UKPLab";
    repo = "sentence-transformers";
    tag = "v${version}";
    hash = "sha256-snowpTdHelcFjo1+hvqpoVt5ROB0f91yt0GsIvA5cso=";
  };

  build-system = [ setuptools ];

  dependencies = [
    huggingface-hub
    pillow
    scikit-learn
    scipy
    torch
    tqdm
    transformers
    typing-extensions
  ];

  optional-dependencies = {
    train = [
      accelerate
      datasets
    ];
    onnx = [ optimum ] ++ optimum.optional-dependencies.onnxruntime;
    # onnx-gpu = [ optimum ] ++ optimum.optional-dependencies.onnxruntime-gpu;
    # openvino = [ optimum-intel ] ++ optimum-intel.optional-dependencies.openvino;
  };

  # Skip tests since they require network access to huggingface.co
  doCheck = false;

  pythonImportsCheck = [ "sentence_transformers" ];

  # Sentence-transformer needs a writable hf_home cache
  postInstall = ''
    export HF_HOME=$(mktemp -d)
  '';

  meta = {
    description = "Multilingual Sentence & Image Embeddings with BERT";
    homepage = "https://github.com/UKPLab/sentence-transformers";
    changelog = "https://github.com/UKPLab/sentence-transformers/releases/tag/${src.tag}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ dit7ya ];
  };
}
