{
  buildPythonPackage,
  fetchFromGitHub,
  lib,
  setuptools,
}:

let
  version = "2026.5.9";
in
buildPythonPackage {
  pname = "regex";
  inherit version;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "mrabarnett";
    repo = "mrab-regex";
    tag = version;
    hash = "sha256-AWwTTVTnXVuoonv4mgzIlwev3a5NA5ayiH6SYDLxRDo=";
  };

  build-system = [ setuptools ];

  # mrab-regex 2026.5.x 使用 PEP 639 形式的 `license` 字符串与 `license-files` 字段。
  # nixpkgs 24.11 自带的 setuptools 75.1.1 仅识别旧格式 `license = { file = ...; text = ... }`，
  # 会把字符串错误解析成同时含 file 和 text 两个 key 的表，配置校验失败。
  # 同时上游声明 `[build-system] requires = ["setuptools > 77.0.3"]`，pypa/build 会据此拒绝旧版。
  # 修复手段：剥掉 license 元数据 + 放宽 setuptools 版本约束；
  # 包功能与 setuptools 版本无强耦合，许可证声明已经在 meta.license 中处理。
  postPatch = ''
    sed -i '/^license = /d;/^license-files = /d' pyproject.toml
    sed -i 's/"setuptools > 77\.0\.3"/"setuptools"/' pyproject.toml
  '';

  doCheck = false;

  pythonImportsCheck = [ "regex" ];

  meta = {
    description = "Alternative regular expression module, to replace re";
    homepage = "https://github.com/mrabarnett/mrab-regex";
    # 上游为 Apache-2.0 + CNRI Python 双许可证。
    # nixpkgs 25.11 已提供 lib.licenses.cnri-python；24.11 无此 attr，故做条件追加。
    license = [
      lib.licenses.asl20
    ] ++ lib.optionals (lib.licenses ? cnri-python) [ lib.licenses.cnri-python ];
  };
}
