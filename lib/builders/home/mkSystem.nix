{ self
, lib

, name
, groups ? [ ]
, hostName ? null
, ...
}: { flake, config, ... }:
let inherit (lib) mkDefault mkForce optionals; in {
  users.users.${name} = {
    isNormalUser = mkDefault true;

    # Only add groups that exist.
    # TODO : Move this to where these programs reside.
    extraGroups = builtins.filter (x: builtins.elem x (builtins.attrNames config.users.groups)) [
      "video"
      "audio"
      "wheel"
      "network"
      "i2c"
      "docker"
      "podman"
      "git"
      "libvirtd"
    ] ++ groups;

    hashedPasswordFile = config.sops.secrets."${name}-passwd".path;
    openssh.authorizedKeys.keys = [ (builtins.readFile "${flake}/home/${name}/id_ed25519.pub") ];
  };

  sops.secrets."${name}-passwd" = {
    sopsFile = "${flake}/hosts/${config.host.name}/secrets.yaml";
    neededForUsers = true;
  };

  home-manager = {
    extraSpecialArgs = {
      flake = self;
      inherit (self) inputs outputs;
    };

    users.${name} = { flake, ... }: {
      home = {
        username = name;
        homeDirectory = mkForce "/home/${name}";

        stateVersion = mkForce "23.11";
        sessionPath = [ "$HOME/.local/bin" ];
      };

      imports = builtins.attrValues (import "${flake}/modules/home-manager") ++ [
        "${flake}/home/shared/global"
      ] ++ (lib.optional (hostName != null) "${flake}/home/${name}/${hostName}.nix");
    };
  };
}
