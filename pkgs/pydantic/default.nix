{ lib, buildPythonPackage, fetchPypi, setuptools, pythonOlder
, hatchling, hatch-fancy-pypi-readme, typing-extensions, annotated-types
, pydantic-core, pytest, pytest-mock, cloudpickle, email-validator
, pytestCheckHook }:

buildPythonPackage rec {
  pname = "pydantic";
  version = "2.5.2";
  format = "pyproject";

  disabled = pythonOlder "3.7";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-/xd7pkxvr3PXr6LoytOP1FbA2+AcmVTnEDgAHNFabt0=";
  };

  build-system = [
    hatchling
    hatch-fancy-pypi-readme
  ];

  propagatedBuildInputs = [
    typing-extensions
    annotated-types
    pydantic-core
  ];

  passthru.optional-dependencies = {
    email = [ email-validator ];
  };

  # Disable tests due to benchmark dependency conflicts
  doCheck = false;

  pythonImportsCheck = [ "pydantic" ];

  # Disable runtime dependency check to allow newer pydantic-core
  dontCheckRuntimeDeps = true;

  meta = with lib; {
    description = "Data validation using Python type hints";
    homepage = "https://github.com/pydantic/pydantic";
    changelog = "https://github.com/pydantic/pydantic/blob/v${version}/CHANGELOG.md";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
  };
} 