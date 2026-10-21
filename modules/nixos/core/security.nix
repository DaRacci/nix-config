# TODO - Look into TPM2
# TODO - Look into SELinux or AppArmour
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf mkOption;
  inherit (lib.types) ints;

  cfg = config.core.security;
in
{
  options.core.security = {
    enable = mkEnableOption "security features" // {
      default = true;
    };

    userLimit = mkOption {
      type = ints.unsigned;
      default = 131072;
      description = ''
        The maximum number of open files per user.

        This is used to set the limits for both PAM and systemd.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Remove once inputs updated but pkgs dont build on it atm so no bump :)
    #TODO:https://github.com/NixOS/nixpkgs/pull/576390
    security.pki.caCertificateBlacklist = [
      # CVE-2026-111943
      "Comodo AAA Services root"
      # https://hg-edge.mozilla.org/projects/nss/rev/26d38a0c3fb81e7fb2acedbaf4c42dd21dce0517
      "emSign ECC Root CA - G3"
      # https://hg-edge.mozilla.org/projects/nss/rev/8159223c48ceeb1273a1915bca95a517294ab0e0
      "emSign Root CA - C1"
      "emSign ECC Root CA - C3"
    ];


    security = {
      lockKernelModules = false;
      protectKernelImage = true;

      polkit.enable = true;

      sudo.enable = false;
      sudo-rs = {
        enable = true;
        execWheelOnly = true;
      };

      tpm2.enable = true;

      pam.loginLimits = [
        # { domain = "@wheel"; item = "nofile"; type = "soft"; value = "524288"; }
        # { domain = "@wheel"; item = "nofile"; type = "hard"; value = "1048576"; }
        {
          domain = "*";
          item = "nofile";
          type = "-";
          value = toString cfg.userLimit;
        }
        # { domain = "*"; item = "memlock"; type = "-"; value = "${toString userLimit}"; }
      ];
    };

    systemd.user.settings.Manager.DefaultLimitNOFILE = cfg.userLimit;

    boot.kernel.sysctl = {
      "fs.file-max" = toString (cfg.userLimit * 4);
    };
  };
}
