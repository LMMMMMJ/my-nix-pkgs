{
  buildPythonPackage,
  fetchFromGitHub,
  lib,
  setuptools,
}:

let
  version = "2026.9.29";
in
buildPythonPackage {
  pname = "regex";
  inherit version;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "mrabarnett";
    repo = "mrab-regex";
    tag = version;
    hash = "sha256-9WiynNc25LhHzooLEU4AubVFc6fXAJnBjqPIvfk/l44=";
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
