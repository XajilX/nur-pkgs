{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.leigod;
  drv = pkgs.callPackage ./package.nix { };
  binary = "${drv}/bin/acc-gw.router.amd64";
  monitor = "${drv}/libexec/steamdeck_monitor.sh";
  accConfig = "${drv}/share/config";
  fakeProductName = "${drv}/share/fake/product_name";
  fakeOSRelease = "${drv}/share/fake/os-release";

in
{
  options.services.leigod = {
    enable = lib.mkEnableOption "Leigod game accelerator";

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/leigod";
      description = ''
        Persistent writable state directory.
        It is exposed to Leigod as /home/leigod.
      '';
    };

    wlan0Mac = lib.mkOption {
      type = lib.types.str;
      example = "02:11:22:33:44:55";
      description = ''
        Stable MAC address used by the dummy wlan0 interface.
        Do not change after setting, otherwise the binding will be invalidated. 
      '';
    };

  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isx86_64 || pkgs.stdenv.hostPlatform.isAarch64;

        message = "services.leigod only supports x86_64 and aarch64.";
      }
    ];

    systemd = {
      tmpfiles.rules = [
        "d ${cfg.stateDir} 0755 root root -"
        "d ${cfg.stateDir}/config 0755 root root -"
        "d /tmp/acc 0755 root root 3d"

        # make binary visible in /home/leigod
        "L+ ${cfg.stateDir}/acc-gw.router.amd64 - - - - ${binary}"
        "L+ ${cfg.stateDir}/steamdeck_monitor.sh - - - - ${monitor}"
        "L+ ${cfg.stateDir}/acc_upgrade_monitor - - - - ${drv}/libexec/acc_upgrade_monitor"
        "L+ ${cfg.stateDir}/config/ipdatacloud_country.xdb - - - - ${accConfig}/ipdatacloud_country.xdb"
      ];

      services.leigod-wlan0 = {
        description = "Leigod compatibility wlan0 interface";

        before = [ "leigod.service" ];
        requiredBy = [ "leigod.service" ];

        path = [
          pkgs.iproute2
          pkgs.coreutils
          pkgs.gnugrep
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          if ! ip link show wlan0 >/dev/null 2>&1; then
            ip link add wlan0 type dummy
          fi
          ip link set wlan0 up
          currentMac="$(cat /sys/class/net/wlan0/address)"
          if [ "$currentMac" != "${cfg.wlan0Mac}" ]; then
            ip link set wlan0 down
            ip link set wlan0 address "${cfg.wlan0Mac}"
          fi
          ip link set wlan0 up
        '';

        preStop = ''
          if ip -d link show wlan0 2>/dev/null | grep -qw dummy; then
            ip link del wlan0
          fi
        '';
      };

      services.leigod = {
        description = "Leigod Steam Deck Accelerator";

        wantedBy = [
          "multi-user.target"
        ];

        wants = [
          "network-online.target"
        ];

        after = [
          "network-online.target"
          "leigod-wlan0.service"
        ];

        requires = [
          "leigod-wlan0.service"
        ];

        path = with pkgs; [
          ipset
          bash
          coreutils
          gnugrep
          gnused
          gawk
          iproute2
          iptables
          procps
        ];

        serviceConfig = {
          Type = "simple";

          # hide real /home
          TemporaryFileSystem = [
            "/home"
          ];
          CapabilityBoundingSet = [
            "CAP_NET_ADMIN"
            "CAP_NET_RAW"
          ];

          BindPaths = [
            "${cfg.stateDir}:/home/leigod"
          ];

          # simulate steamdeck
          BindReadOnlyPaths = [
            "${fakeProductName}:/sys/class/dmi/id/product_name"
            "${fakeOSRelease}:/etc/os-release"
          ];
          ExecStart = "/home/leigod/steamdeck_monitor.sh exec";

          Restart = "always";
          RestartSec = 3;
        };
      };
    };
  };
}
