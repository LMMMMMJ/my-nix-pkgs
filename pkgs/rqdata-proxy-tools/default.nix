{
  buildEnv,
  python3,
  ruijie-sslvpn-cli,
  bubblewrap,
  slirp4netns,
  dante,
  iproute2,
  nettools,
  coreutils,
  bash,
  socat,
  jq,
  openssl,
}:

# 只组合工具；不启动 VPN、设置全局代理或安装系统服务。
buildEnv {
  name = "rqdata-proxy-tools";
  paths = [
    ruijie-sslvpn-cli
    bubblewrap
    slirp4netns
    dante
    iproute2
    nettools
    coreutils
    bash
    socat
    jq
    openssl
    (python3.withPackages (ps: [ ps.rqdatac ]))
  ];
  pathsToLink = [
    "/bin"
    "/sbin"
    "/share/man"
  ];
  meta = {
    description = "Tools for an isolated SSLVPN and a per-client RQData SOCKS proxy";
    platforms = [ "x86_64-linux" ];
  };
}
