{ upstream, fetchFromGitHub }:

# 复用 nixpkgs 的依赖和可选功能配置，只维护比上游较新的版本。
upstream.overridePythonAttrs (old: rec {
  version = "5.20.1";
  src = fetchFromGitHub {
    owner = "huggingface";
    repo = "transformers";
    tag = "v${version}";
    hash = "sha256-ltsfDeSLhyVTEZB54YUGVQ9cbiB3cPM4i/XTjBHvfWY=";
  };
  meta = old.meta // {
    changelog = "https://github.com/huggingface/transformers/releases/tag/v${version}";
  };
})
