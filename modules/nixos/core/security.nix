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
      default = 32768;
      description = ''
        The maximum number of open files per user.

        This is used to set the limits for both PAM and systemd.
      '';
    };
  };

  config = mkIf cfg.enable {
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

    systemd.user.extraConfig = "DefaultLimitNOFILE=${toString cfg.userLimit}";

    boot.kernel.sysctl = {
      "fs.file-max" = 65536;
    };
  };
}
