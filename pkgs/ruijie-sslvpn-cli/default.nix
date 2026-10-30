{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  dbus,
  zlib,
  coreutils,
  gawk,
  iproute2,
  nettools,
  psmisc,
  lsb-release,
  dmidecode,
}:

stdenv.mkDerivation {
  pname = "ruijie-sslvpn-cli";
  version = "3.5.0.1789643503";

  # 官方 Linux_64 安装包；地址不含下载接口返回的临时签名。
  src = fetchurl {
    url = "https://cloudsafe.oss-cn-hangzhou.aliyuncs.com/opt/app/file_temp/sslvpn/2026-09-29/sg3q6xqi/RG-SSLVPN_Linux-3.5.0/Linux_64/3.5.0/RG-SSLVPN_Linux_x86_64_3.5.0_Build20260917_Setup.deb";
    hash = "sha256-0/9Ay83BL6C2YX90MnxQYH9iqBOQ9WmVaVseaXxdH6g=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    dbus.lib
    zlib
  ];
  strictDeps = true;
  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --extract "$src" source
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec/ruijie-sslvpn" "$out/bin"
    cp source/usr/local/sslvpn/vpn_cli "$out/libexec/ruijie-sslvpn/"
    cp source/usr/local/sslvpn/sslvpn.cfg "$out/libexec/ruijie-sslvpn/"
    cp -r source/usr/local/sslvpn/lang "$out/libexec/ruijie-sslvpn/"
    chmod +x "$out/libexec/ruijie-sslvpn/vpn_cli"
    makeWrapper "$out/libexec/ruijie-sslvpn/vpn_cli" "$out/bin/ruijie-sslvpn-cli" \
      --add-flags "--cwd $out/libexec/ruijie-sslvpn" \
      --prefix PATH : ${
        lib.makeBinPath [
          coreutils
          gawk
          iproute2
          nettools
          psmisc
          lsb-release
          dmidecode
        ]
      }
    runHook postInstall
  '';

  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/ruijie-sslvpn-cli" --help > help.txt
    grep -F -- '--config' help.txt
    grep -F '3.5.0' help.txt
    test -s "$out/libexec/ruijie-sslvpn/lang/intl_en.arb"
    test -s "$out/libexec/ruijie-sslvpn/sslvpn.cfg"
    runHook postInstallCheck
  '';

  meta = {
    description = "Ruijie SSLVPN command-line client for EG/NBR gateways";
    homepage = "https://secloud1.ruijie.com.cn/SSLVPNClient";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "ruijie-sslvpn-cli";
  };
}
