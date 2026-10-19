{ config, lib, pkgs, ... }:

let
  cfg = config.services.collieMobile;
  userNames = builtins.attrNames cfg.users;
  ports = map (name: cfg.users.${name}.port) userNames;

  # 两个命令使用同一段实现，保证 socket 的选择一致。
  tailscaleCommand = ''
    exec ${cfg.tailscalePackage}/bin/tailscale \
      --socket="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/collie-tailscale/tailscaled.sock" \
      "$@"
  '';
  collieTailscale = pkgs.writeShellScriptBin "collie-tailscale" tailscaleCommand;
  tailscaleForCollie = pkgs.writeShellScriptBin "tailscale" tailscaleCommand;

  collie = pkgs.writeShellScriptBin "collie" ''
    set -eu
    env_file="/etc/collie-mobile/$(${pkgs.coreutils}/bin/id -un).env"
    if [ ! -r "$env_file" ]; then
      echo "This user is not configured in services.collieMobile.users." >&2
      exit 1
    fi
    set -a
    . "$env_file"
    set +a
    # Collie CLI 会让用户 .env 覆盖进程环境变量，拒绝重复定义以防两端配置不同。
    user_env="$HERDR_PLUGIN_CONFIG_DIR/.env"
    if [ -f "$user_env" ]; then
      while IFS='=' read -r key ignored; do
        if ${pkgs.gnugrep}/bin/grep -Eq "^[[:space:]]*(export[[:space:]]+)?$key[[:space:]]*=" "$user_env"; then
          echo "Remove $key from $user_env; manage it in services.collieMobile instead." >&2
          exit 1
        fi
      done < "$env_file"
    fi
    export PATH="${tailscaleForCollie}/bin:$PATH"
    exec ${cfg.colliePackage}/bin/collie "$@"
  '';

  userEnvironment = name: user:
    let
      home = config.users.users.${name}.home;
      values = {
        COLLIE_MUX = "herdr";
        COLLIE_INSTANCE = "";
        COLLIE_HOST = "127.0.0.1";
        COLLIE_PORT = toString user.port;
        COLLIE_TRUSTED_USER = user.tailnetLogin;
        COLLIE_TRUSTED_USER_OPTIONAL = "0";
        COLLIE_SKIP_SERVE = "0";
        COLLIE_SERVE_MODE = "https";
        COLLIE_SERVE_PORT = "443";
        COLLIE_ALLOW_ANY_HOST = "0";
        COLLIE_STATE_DIR = "${home}/.local/state/collie";
        HERDR_PLUGIN_CONFIG_DIR = "${home}/.config/herdr/plugins/config/herdr.collie";
        HERDR_SOCKET_PATH = "${home}/.config/herdr/herdr.sock";
      };
    in
    # 单引号同时适用于 shell 的 source 和 systemd 的 EnvironmentFile。
    lib.concatStringsSep "\n"
      (lib.mapAttrsToList (key: value: "${key}=${lib.escapeShellArg value}") values)
    + "\n";
in
{
  options.services.collieMobile = {
    enable = lib.mkEnableOption "per-user Collie access over Tailscale";
    colliePackage = lib.mkOption {
      type = lib.types.package;
      description = "Collie package exposing bin/collie, including its web assets.";
    };
    herdrPackage = lib.mkOption {
      type = lib.types.package;
      description = "Herdr package exposing bin/herdr.";
    };
    tailscalePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.tailscale;
      defaultText = lib.literalExpression "pkgs.tailscale";
      description = "Tailscale package shared by the CLI wrappers and user daemon.";
    };
    users = lib.mkOption {
      default = { };
      description = "Existing Unix users allowed to run their own Collie instance.";
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          port = lib.mkOption {
            type = lib.types.port;
            description = "Unique host loopback port for this user's Collie bridge.";
          };
          tailnetLogin = lib.mkOption {
            type = lib.types.strMatching "[A-Za-z0-9_.+@-]+";
            description = "Exact Tailscale login name of the phone's owner.";
          };
        };
      });
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = userNames != [ ];
        message = "services.collieMobile.users must contain at least one user.";
      }
      {
        assertion = builtins.length ports == builtins.length (lib.unique ports);
        message = "Each Collie user needs a distinct loopback port.";
      }
    ] ++ map (name: {
      assertion = config.users.users.${name}.isNormalUser
        && builtins.match "[a-z_][a-z0-9_-]*" name != null
        && cfg.users.${name}.port >= 1024;
      message = "Collie requires an existing normal user, a simple Unix name, and a port >= 1024: ${name}";
    }) userNames;

    # 不把原始 Collie 包或内部 tailscale 包加入全局 PATH，以免命令重名。
    environment.systemPackages = [ collie collieTailscale cfg.herdrPackage cfg.tailscalePackage ];
    environment.etc = lib.mapAttrs' (name: user:
      lib.nameValuePair "collie-mobile/${name}.env" {
        text = userEnvironment name user;
        mode = "0644";
      }) cfg.users;

    # 退出最后一个 SSH 会话后仍保留用户服务，开机时启动用户管理器。
    users.users = lib.genAttrs userNames (_: { linger = true; });

    systemd.user.services.collie-tailscaled = {
      description = "Per-user Tailscale for Collie";
      wantedBy = [ "default.target" ];
      unitConfig.ConditionUser = map (name: "|${name}") userNames;
      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          "${cfg.tailscalePackage}/bin/tailscaled"
          "--tun=userspace-networking"
          "--socket=%t/collie-tailscale/tailscaled.sock"
          "--statedir=%S/collie-tailscale"
          "--port=0"
        ];
        RuntimeDirectory = "collie-tailscale";
        RuntimeDirectoryMode = "0700";
        StateDirectory = "collie-tailscale";
        StateDirectoryMode = "0700";
        UMask = "0077";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # collie start 生成主 unit；NixOS 只提供覆盖文件。
    # 后台进程不读取交互 shell 的 PATH，因此这里也必须加入同一 socket 包装器。
    systemd.user.services.collie = {
      overrideStrategy = "asDropin";
      wants = [ "collie-tailscaled.service" ];
      after = [ "collie-tailscaled.service" ];
      unitConfig.ConditionUser = map (name: "|${name}") userNames;
      path = [
        tailscaleForCollie
        cfg.herdrPackage
        "/run/wrappers"
        "%h/.nix-profile"
        "/etc/profiles/per-user/%u"
        "/run/current-system/sw"
      ];
      # 本文件排在 Collie 生成的 EnvironmentFile 之后，同名变量以本文件为准。
      serviceConfig.EnvironmentFile = [ "/etc/collie-mobile/%u.env" ];
    };
  };
}
