{ lib, buildPythonPackage, fetchPypi, setuptools, pythonOlder, autoPatchelfHook
, requests, six, pandas, cachetools, protobuf, lxml, beautifulsoup4, tqdm }:
let
  url =
    "https://files.pythonhosted.org/packages/33/3e/d426a56e5feac9b0aaada1c6b0745ed03422d4a713295e0bbb44c8ea86fe/tushare-1.4.29-py3-none-any.whl";
in buildPythonPackage rec {
  pname = "tushare";
  version = "1.4.29";
  format = "wheel";
  src = builtins.fetchurl {
    inherit url;
    sha256 = "sha256-glVK+VPqWsPYdx1CMwSTGBAxx+aNzM4DpJHHNW6bpLI=";
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
