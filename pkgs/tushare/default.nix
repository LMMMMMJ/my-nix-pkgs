{ lib, buildPythonPackage, fetchPypi, setuptools, pythonOlder, autoPatchelfHook
, requests, six, pandas, cachetools, protobuf, lxml, beautifulsoup4, tqdm }:
let
  url =
    "https://files.pythonhosted.org/packages/80/75/63810958023595b460f2a5ef6baf5a60ffd8166e5fc06a3c2f22e9ca7b34/tushare-1.4.24-py3-none-any.whl";
in buildPythonPackage rec {
  pname = "tushare";
  version = "1.4.24";
  format = "wheel";
  src = builtins.fetchurl {
    inherit url;
    sha256 = "sha256:020v8lj28rbn4zggnkwv4c6546ndwsjybhnsv86cnir74ql333kp";
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
