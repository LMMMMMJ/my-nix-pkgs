{ lib, buildPythonPackage, fetchPypi, setuptools, pythonOlder, autoPatchelfHook
, requests, six, pandas, cachetools, protobuf, lxml, beautifulsoup4, tqdm }:
let
  url =
    "https://files.pythonhosted.org/packages/df/6d/a42651d8c610fcaa579985d6525609bc227bbf3895e2a4f41fe236e335bc/tushare-1.4.25-py3-none-any.whl";
in buildPythonPackage rec {
  pname = "tushare";
  version = "1.4.25";
  format = "wheel";
  src = builtins.fetchurl {
    inherit url;
    sha256 = "sha256-LdH76Gib9j2Dgkj6NMHjAfDE8HaN3VFdX5c0f+EJaT4=";
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
