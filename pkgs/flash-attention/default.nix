{
  lib,
  stdenv,
  buildPythonPackage,
  python,
  autoPatchelfHook,
  einops,
  torch,
}:

let
  version = "2.8.1";
  # Prebuilt CUDA wheel from upstream — flash-attn does not publish wheels to
  # PyPI. The wheel's CUDA major must match the torch it runs against, or the
  # extension fails at import with `libcudart.so.<major>: cannot open shared
  # object file`; the build cannot catch that, because the wheel is only
  # unpacked and `autoPatchelfIgnoreMissingDeps` defers resolution to runtime.
  # This flake's torch is cu130, so the pin is cu13 + cp313. 2.8.3 is newer but
  # publishes cu13 for cp312 only.
  wheel = "flash_attn-${version}+cu13torch2.10cxx11abiTRUE-cp313-cp313-linux_x86_64.whl";
in
buildPythonPackage {
  pname = "flash-attn";
  inherit version;
  format = "wheel";

  src = builtins.fetchurl {
    url = "https://github.com/Dao-AILab/flash-attention/releases/download/v${version}/${wheel}";
    sha256 = "sha256-oU/qFX62Hf7lb2BaJKemFQcEUXdZEls5Qt0Ev/oF1s8=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  # The wheel pins torch==2.10.*; flake provides 2.12.1 — relax it.
  pythonRelaxDeps = [ "torch" ];

  propagatedBuildInputs = [
    einops
    torch
  ];

  # Wheel ships CUDA-linked .so files. Without libcuda/libtorch_cuda in the
  # closure autoPatchelf would fail; defer resolution to runtime LD_LIBRARY_PATH.
  autoPatchelfIgnoreMissingDeps = true;

  # torch propagates a ninja setup hook that hijacks the default buildPhase;
  # wheels don't need building, so skip it.
  dontBuild = true;

  doCheck = false;
  # importing flash_attn loads the CUDA C extension — only succeeds with a
  # CUDA-enabled torch + driver, which this flake's CPU torch does not provide.
  dontUsePythonImportsCheck = true;

  meta = {
    description = "Fast and memory-efficient exact attention";
    homepage = "https://github.com/Dao-AILab/flash-attention";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
    # Wheel is built for cp313; mark broken on other interpreters so the
    # mismatch surfaces at eval time instead of at runtime.
    broken = python.pythonVersion != "3.13";
  };
}
