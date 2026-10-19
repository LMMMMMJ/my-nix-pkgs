{ lib, buildPythonPackage, fetchPypi, requests, pandas, numpy, tqdm }:
buildPythonPackage rec {
  pname = "xtquant";
  version = "250807.1.2";
  format = "wheel";
  src = fetchPypi {
    inherit pname version format;
    dist = "py3";
    python = "py3";
    hash = "sha256-kfGf+akpccWr5k+9B35SEuBBjwggqjQnrvNEQjD3KSE=";
  };

  propagatedBuildInputs = [
    requests
    pandas
    numpy
    tqdm
  ];
  doCheck = false;

  pythonImportsCheck = [ "xtquant" ];
  meta = with lib; {
    description = "Python SDK for the XtQuant QMT trading platform";
    homepage = "https://pypi.org/project/xtquant";
    license = licenses.unfree;
  };
}
