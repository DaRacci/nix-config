{ self
, pkgsFor ? null
, system ? null
, pkgs ? pkgsFor system

, name
, users ? [ ]
, deviceType
, ...
}:
let
  hostDir =
    let
      opt1 = "${self}/hosts/${name}";
      opt2 = "${self}/hosts/servers/${name}";
    in
    if (builtins.pathExists opt1) then opt1 else opt2;
in
{
  inherit system;

  modules = [
    "${self}/hosts/common/global"
    "${self}/hosts/device/common"
    "${self}/hosts/device/${deviceType}"
    "${hostDir}"

    ({ inputs, ... }: {
      imports = [ inputs.home-manager.nixosModule ];

      host.name = name;
      passthru.enable = false; # Why does build break without this?

      system.stateVersion = "23.11";
    })
  ] ++ (builtins.map (username: (import ../home/mkSystemHome.nix { inherit self pkgs username; })) users);

  specialArgs = {
    flake = self;
    inherit hostDir;
    inherit (self) inputs outputs;
  };
}
