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
  ];

  options = {
    host.name = lib.mkOption { type = lib.types.str; };
    host.system = lib.mkOption { type = lib.types.nullOr lib.types.str; };
    server.ioPrimaryHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    server.monitoringPrimaryHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    server.distributedBuilds.builders = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    server.tests = lib.mkOption {
      type = lib.types.attrsOf lib.types.unspecified;
      default = { };
    };
    server.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = {
    host.name = hostName;
    host.system = "x86_64-linux";
    host.device.role = "server";
    networking.hostName = hostName;
    system.name = hostName;
  };
}
