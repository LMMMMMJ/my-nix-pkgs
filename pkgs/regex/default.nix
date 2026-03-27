{
  buildPythonPackage,
  fetchFromGitHub,
  lib,
  setuptools,
}:

let
  version = "2026.2.28";
in
buildPythonPackage {
  pname = "regex";
  inherit version;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "mrabarnett";
    repo = "mrab-regex";
    tag = version;
    hash = "sha256-Izg+i4LCPIjesJ8o9mYqjzhMQ4HmRmBd3QsDJRbB/oI=";
  };

  build-system = [ setuptools ];

  doCheck = false;

  pythonImportsCheck = [ "regex" ];

  meta = {
    description = "Alternative regular expression module, to replace re";
    homepage = "https://github.com/mrabarnett/mrab-regex";
    license = [
      lib.licenses.asl20
      lib.licenses.cnri-python
    ];
  };
}
