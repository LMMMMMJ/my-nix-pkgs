{
  fetchFromGitHub,
  buildGoModule,
  lib,
  versionCheckHook,
}:
buildGoModule rec {
  pname = "baidupcs-go";
  version = "4.0.1";

  src = fetchFromGitHub {
    owner = "qjfoidnh";
    repo = "BaiduPCS-Go";
    rev = "v${version}";
    hash = "sha256-AvwdAOjuQxdmhg+IJxQ9e9iMXqveLjoF/W7ntZZmES4=";
  };

  vendorHash = "sha256-oOZeBCHpAasi9K77xA+8HxZErGWKwb4OaWzWhHagtQE=";
  doCheck = false;

  ldflags = [
    "-X main.Version=v${version}"
  ];

  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  doInstallCheck = true;
  versionCheckProgram = "${placeholder "out"}/bin/${meta.mainProgram}";

  postInstall = ''
    rm -f $out/bin/AndroidNDKBuild
  '';

  postVersionCheck = ''
    rm -f $out/bin/pcs_config.json
  '';

  meta = {
    mainProgram = "BaiduPCS-Go";
    description = "Baidu Netdisk commandline client, mimicking Linux shell file handling commands";
    homepage = "https://github.com/qjfoidnh/BaiduPCS-Go";
    license = lib.licenses.asl20;
  };
}
