{
  self,
  hostName,
  allocations,
}:
{ lib, ... }: {
  imports = [
    (import "${self}/modules/flake/apply/system.nix" {
      inherit allocations hostName;
      deviceType = "server";
    })
    "${self}/modules/nixos/core/host/device.nix"
  ]
  # Import production module tree so services get provisioned
  # NOTE: do NOT import hosts/server/shared — it pulls profiles/headless.nix
  # which requires kernel config unavailable in QEMU test context.
  ++ (builtins.attrValues (import "${self}/modules/nixos"))
  ++ [
    "${self}/modules/nixos/server"
    "${self}/hosts/server/${hostName}"
  ];

  options = {
    host.name = lib.mkOption { type = lib.types.str; };
    host.system = lib.mkOption { type = lib.types.nullOr lib.types.str; };
  };

  config = {
    host.name = hostName;
    host.system = "x86_64-linux";
    host.device.role = "server";
    networking.hostName = hostName;
    system.name = hostName;
  };
}
