{ self

, pkgsFor ? null
, system ? null
, pkgs ? pkgsFor system

, username
, args ? { }
, ...
}:
let inherit (pkgs.lib) optional; in {
  inherit pkgs;

  modules = [
    ({ flake, host, config, lib, ... }: {
      home = {
        inherit username;
        homeDirectory = lib.mkForce "/home/${username}";

        stateVersion = lib.mkForce "23.11";
        sessionPath = [ "$HOME/.local/bin" ];
      };

      imports = [
        "${flake}/home/common/global"
      ] ++ optional (host != null && (builtins.hasAttr "name" host) && host.name != null) [ "${flake}/home/${host.name}.nix" ];
    })
  ];

  extraSpecialArgs = {
    host = null;
    flake = self;
    inherit (self) inputs outputs;
  } // args;
}

