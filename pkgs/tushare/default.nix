{ lib, buildPythonPackage, fetchPypi, setuptools
, requests, six, pandas, cachetools, protobuf, lxml, beautifulsoup4, tqdm
, simplejson, websocket-client }:
buildPythonPackage rec {
  pname = "tushare";
  version = "1.4.29";
  format = "wheel";
  src = fetchPypi {
    inherit pname version format;
    dist = "py3";
    python = "py3";
    hash = "sha256-glVK+VPqWsPYdx1CMwSTGBAxx+aNzM4DpJHHNW6bpLI=";
  };

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
    simplejson
    websocket-client
  ];
  # Wheel metadata lists `bs4` (a stub for beautifulsoup4 on PyPI); nixpkgs
  # only ships beautifulsoup4 directly, so drop the stub from the dep check.
  pythonRemoveDeps = [ "bs4" ];
  doCheck = false;

  pythonImportsCheck = [ "tushare" ];
  meta = with lib; {
    description = "tushare";
    homepage = "https://pypi.org/project/tushare";
    license = licenses.asl20;
    maintainers = with maintainers; [ fab ];
  };
}
