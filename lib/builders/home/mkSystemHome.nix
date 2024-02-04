{ self
, system ? null
, pkgsFor ? null
, pkgs ? pkgsFor system

, username
, groups ? [ ]
, shell ? pkgs.fish
, ...
}: { flake, host, config, ... }:
let inherit (pkgs.lib) mkDefault; in {
  users.users.${username} = {
    inherit shell;
    isNormalUser = mkDefault true;

    # Only add groups that exist.
    # TODO : Move this to where these programs reside.
    extraGroups = (builtins.filter (x: builtins.elem x (builtins.attrNames config.users.groups)) [
      "video"
      "audio"
      "wheel"
      "network"
      "i2c"
      "docker"
      "podman"
      "git"
      "libvirtd"
    ] ++ groups);

    hashedPasswordFile = config.sops.secrets."${username}-passwd".path;
    openssh.authorizedKeys.keys = [ (builtins.readFile "${flake}/home/${username}/id_ed25519.pub") ];
  };

  sops.secrets."${username}-passwd" = {
    sopsFile = "${flake}/hosts/${host.name}/secrets.yaml";
    neededForUsers = true;
  };

  home-manager = let hmBase = import ./mkHmHome.nix { inherit self pkgs username; args = { host = { host = config.host; }; }; }; in {
    inherit (hmBase) extraSpecialArgs;

    users.${username} = builtins.elemAt hmBase.modules 0;
  };
}
