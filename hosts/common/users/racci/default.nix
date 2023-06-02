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

    openssh.authorizedKeys.keys = [ (builtins.readFile ../../../../home/${username}/ssh.pub) ];
    passwordFile = config.age.secrets."${username}-passwd".path;
    packages = [ pkgs.home-manager ];
  };

  sops.secrets."${username}-passwd" = {
    sopsFile = ../../secrets.yaml;
    neededForUsers = true;
  };

  home-manager.users.${username} = import ../../../../home/racci/${hostName}.nix;

  services = {
    geoclue2.enable = true;
    openssh = {
      enable = true;
      permitRootLogin = "no";
      passwordAuthentication = false;
    };
  };
}
