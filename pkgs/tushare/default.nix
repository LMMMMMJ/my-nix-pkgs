{ lib, buildPythonPackage, fetchPypi, setuptools, pythonOlder, autoPatchelfHook
, requests, six, pandas, cachetools, protobuf, lxml, beautifulsoup4, tqdm }:
let
  url =
    "https://files.pythonhosted.org/packages/38/33/0b4ed09bff3b69887c2545f1c587420c89685d36c377095e465cc000759b/tushare-1.4.21-py3-none-any.whl";
in buildPythonPackage rec {
  pname = "tushare";
  version = "1.4.21";
  format = "wheel";
  src = builtins.fetchurl {
    inherit url;
    sha256 = "sha256:0z1zb500xas4b4i3kb3ai6hmim2d2ydzzvr5fgd3dvlcdn3c6510";
  };

  build-system = [ setuptools ];
  propagatedBuildInputs = [
    setuptools
    six
    pandas
    cachetools
    protobuf
    lxml
    requests
    beautifulsoup4
    tqdm
  ];
  doCheck = false;
  nativeBuildInputs = [ autoPatchelfHook ];

  pythonImportsCheck = [ "tushare" ];
  meta = with lib; {
    description = "tushare";
    homepage = "https://pypi.org/project/tushare";
    license = licenses.asl20;
    maintainers = with maintainers; [ fab ];
  };
}
