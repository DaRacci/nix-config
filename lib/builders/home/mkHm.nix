{ self

, pkgsFor ? null
, system ? null
, pkgs ? pkgsFor system

, name
, args ? { }
, ...
}: {
  inherit pkgs;

  modules = [
    ({ flake, host, config, lib, ... }: {
      home = {
        username = name;
        homeDirectory = lib.mkForce "/home/${name}";

        stateVersion = lib.mkForce "23.11";
        sessionPath = [ "$HOME/.local/bin" ];
      };

      imports = [
        "${flake}/home/common/global"
      ] ++ (pkgs.lib.optionals (host != null && host.name != null) [ "${flake}/home/${name}/${host.name}.nix" ]);
    })
  ];

  extraSpecialArgs = {
    host = null;
    flake = self;
    inherit (self) inputs outputs;
  } // args;
}

