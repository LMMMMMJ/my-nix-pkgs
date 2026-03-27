{ lib, buildPythonPackage, setuptools, requests, pandas, numpy, tqdm }:
let
  url =
    "https://files.pythonhosted.org/packages/f4/23/3c8aa2d1130aa735285fb7e18a44d67ab71ba1162e545bd488b20457d57b/xtquant-250516.1.1-py3-none-any.whl";
in buildPythonPackage rec {
  pname = "xtquant";
  version = "250516.1.1";
  format = "wheel";
  src = builtins.fetchurl {
    inherit url;
    sha256 = "sha256:f8461b0a295fa9b13ead33acca8675f7961fe1b4488a319b5549853142a89014";
  };

  build-system = [ setuptools ];
  propagatedBuildInputs = [
    requests
    pandas
    numpy
    tqdm
  ];
  doCheck = false;

  pythonImportsCheck = [ "xtquant" ];
  meta = with lib; {
    description = "XtQuant - 迅投QMT量化交易Python SDK";
    homepage = "https://pypi.org/project/xtquant";
    license = licenses.unfree;
  };
}
