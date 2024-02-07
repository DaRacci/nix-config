{ self
, system ? null
, pkgsFor ? null
, pkgs ? pkgsFor system

, name
, groups ? [ ]
, shell ? pkgs.nushell
, ...
}: { flake, config, ... }:
let inherit (pkgs.lib) mkDefault; in {
  users.users.${name} = {
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

    hashedPasswordFile = config.sops.secrets."${name}-passwd".path;
    openssh.authorizedKeys.keys = [ (builtins.readFile "${flake}/home/${name}/id_ed25519.pub") ];
  };

  sops.secrets."${name}-passwd" = {
    sopsFile = "${flake}/hosts/${config.host.name}/secrets.yaml";
    neededForUsers = true;
  };

  home-manager = let hmBase = import ./mkHm.nix { inherit self pkgs name; args = { host = config.host; }; }; in {
    inherit (hmBase) extraSpecialArgs;

    users.${name} = builtins.elemAt hmBase.modules 0;
  };
}
