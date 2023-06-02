# TODO :: Make this file like kinda templatable?? like the import parts and passwd files.
{ pkgs, config, ... }:
let
  inherit (config.networking) hostName;
  username = "racci";
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in {
  users.mutableUsers = false;
  users.users.${username} = {
    isNormalUser = true;
    shell = pkgs.nushell;
    extraGroups = [
      "wheel"
      "video"
      "audio"
    ] ++ ifTheyExist [
      "network"
      "i2c"
      "docker"
      "podman"
      "git"
      "libvirtd"
    ];

    # openssh.authorizedKeys.keys = [ (builtins.readFile ../../../../home/${username}/ssh.pub) ];
    # passwordFile = config.age.secrets."${username}-passwd".path;
    hashedPassword = "$6$sqBxegZBhK94z/hT$nHMZdr51KMDPl0/ZhGqqnilsLMavskMYeAsvdLEIXYwbhaXcDXAz4Pp4iQxeprKCD6NA1joTvrLpknTentWY..";
    packages = [ pkgs.home-manager ];
  };

  # sops.secrets."${username}-passwd" = {
  #   sopsFile = ../../secrets.yaml;
  #   neededForUsers = true;
  # };

  # home-manager.users.${username} = import ../../../../home/${username}/${hostName}.nix;

  services = {
    geoclue2.enable = true;
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
  };
}
