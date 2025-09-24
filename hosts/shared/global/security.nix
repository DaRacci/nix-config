# TODO - Look into TPM2
# TODO - Look into SELinux or AppArmour
let
  userLimit = 32768;
in
{
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
        value = "${toString userLimit}";
      }
      # { domain = "*"; item = "memlock"; type = "-"; value = "${toString userLimit}"; }
    ];
  };

  systemd.user.extraConfig = "DefaultLimitNOFILE=${toString userLimit}";

  boot.kernel.sysctl = {
    "fs.file-max" = 65536;
  };
}
