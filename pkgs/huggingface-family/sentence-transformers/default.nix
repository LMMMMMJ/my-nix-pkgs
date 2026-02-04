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
  version = "5.2.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "huggingface";
    repo = "sentence-transformers";
    tag = "v${version}";
    hash = "sha256-+ZJb56yo58nJtQz6LIyqsQA4yAFuDGeRRlkj0+iwUJ4=";
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
    homepage = "https://github.com/huggingface/sentence-transformers";
    changelog = "https://github.com/huggingface/sentence-transformers/releases/tag/${src.tag}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ dit7ya ];
  };
}
