{
  lib,
  stdenv,
  buildPythonPackage,
  fetchurl,
  autoPatchelfHook,
  python,
  brotli,
  msgpack,
  numpy,
  orjson,
  pandas,
  python-dateutil,
  python-rapidjson,
  python-socks,
  six,
  zstandard,
}:

let
  sources = lib.importJSON ./sources.json;
  pythonTag = "cp${lib.replaceStrings [ "." ] [ "" ] python.pythonVersion}";
  wheels = sources.wheels.${pythonTag} or { };
  wheel =
    wheels.${stdenv.hostPlatform.system}
      or (throw "rqdatac ${sources.version}: no wheel for ${pythonTag} on ${stdenv.hostPlatform.system}");
in
buildPythonPackage {
  pname = "rqdatac";
  inherit (sources) version;
  format = "wheel";

  # 上游仅发布 CPython wheel，不支持 PyPy、自由线程 ABI 或 musl。
  disabled =
    python.implementation != "cpython"
    || !(lib.elem pythonTag python.pythonABITags)
    || !(builtins.hasAttr stdenv.hostPlatform.system wheels)
    || stdenv.hostPlatform.isMusl;

  src = fetchurl {
    inherit (wheel) url hash;
  };

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  dependencies = [
    brotli
    msgpack
    numpy
    orjson
    pandas
    python-dateutil
    python-rapidjson
    # 包含上游 proxy extra，供 RQData 自身的连接使用 SOCKS/HTTP 代理。
    python-socks
    six
    zstandard
  ];

  # wheel 未附测试；安装后验证实际扩展及传输编解码，不初始化远程账户。
  doCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    PYTHONPATH="$out/${python.sitePackages}:$PYTHONPATH" \
      ${python.interpreter} ${./smoke-test.py} ${sources.version}
    runHook postInstallCheck
  '';

  pythonImportsCheck = [
    "rqdatac"
    "rqdatac.connection"
    "rqdatac.services.financial"
    "rqdatac.services.convertible"
  ];

  meta = {
    description = "RiceQuant RQData financial data Python client";
    homepage = "https://www.ricequant.com/doc/rqdata/python/index-rqdatac";
    changelog = "https://www.ricequant.com/doc/rqdata/python/changelogs";
    # 官方 wheel 及 PyPI 元数据没有声明开源许可证。
    license = lib.licenses.unfree;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
