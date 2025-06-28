{ lib, buildPythonPackage, fetchPypi, setuptools, pythonOlder, six }:

buildPythonPackage rec {
  pname = "PyExecJS";
  version = "1.5.1";
  format = "setuptools";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-NMwdBwl2kYGD/3vcCtcfgVeokcknCMAMX7v/enafUFw=";
  };

  build-system = [ setuptools ];
  
  propagatedBuildInputs = [ six ];

  # PyExecJS doesn't have proper tests in the tarball
  doCheck = false;

  pythonImportsCheck = [ "execjs" ];

  meta = with lib; {
    description = "Run JavaScript code from Python";
    homepage = "https://pypi.org/project/PyExecJS/";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
  };
} 