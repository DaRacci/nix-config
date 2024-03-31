{ self
, lib
, system

, name
, users ? [ ]
, deviceType
, ...
}:
let
  # TODO - Remove this, and use the new haumea lib
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
      imports = [ inputs.home-manager.nixosModule inputs.nixos-generators.nixosModules.all-formats ];

      host = {
        inherit name system;
      };

      passthru.enable = false; # Why does build break without this?

      host.device.role = deviceType;

      system.stateVersion = "23.11";
    })
  ] ++ (builtins.map (name: (import ../home/mkSystem.nix { inherit self lib name; })) users);

  specialArgs = {
    flake = self;
    inherit (self.inputs) nix-colours;
    inherit hostDir;
    inherit (self) inputs outputs;

    haumea = haumea.hosts.${deviceType}.${name};
    haumeaCommon = haumea.hosts.common;
  };
}
