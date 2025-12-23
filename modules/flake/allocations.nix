# This is a special configuration file that will be used to define
# special options across all NixOS Configurations in this flake.
#
# The most common use case will be for designating certain machines as
# primaries for different services such as databases.
#
# Options in the file will be parsed to each system via specialArgs during their
# declaration in the flake-module.nix file, this file serves only to define those options.
{
  self,
  lib,
  ...
}:
let
  inherit (lib) builders types mkOption;
  inherit (builders) getHostsByType;
  inherit (types)
    attrsOf
    listOf
    enum
    str
    ;

  hostsByType = getHostsByType self;
  serverHostnamesEnum = enum hostsByType.server;
in
{
  options.allocations = {
    accelerators = mkOption {
      type = attrsOf (
        listOf (enum [
          "cuda"
          "rocm"
        ])
      );
      default = { };
      description = ''
        Define hardware accelerators allocated to a machine by hostname.

        The attribute names are hostnames, and the values are lists of
        accelerator types assigned to that host.
      '';
      example = {
        cudaAndRocmHost = [
          "cuda"
          "rocm"
        ];
        onlyRocm = [ "rocm" ];
        nothing = [ ]; # This could be omitted.
      };
    };

    hostTypes = mkOption {
      type = attrsOf (listOf str);
      readOnly = true;
      description = ''
        An Attribute set defining hostnames by their device type.
        The attribute names are device types, and the values are lists of
        hostnames assigned to that device type.
      '';
      example = {
        server = [
          "nixbuild1"
          "nixbuild2"
        ];
        desktop = [
          "workstation1"
        ];
      };
      default = hostsByType;
    };

    server = {
      ioPrimaryCoordinator = mkOption {
        type = serverHostnamesEnum;
        description = ''
          Designate a server to act as the Primary I/O coordinator
        '';
      };

      distributedBuilders = mkOption {
        type = listOf serverHostnamesEnum;
        default = [ ];
        description = ''
          List of servers that will act as remote builders for server-side distributed builds.
        '';
        example = [
          "nixbuild1"
          "nixbuild2"
        ];
      };
    };
  };

  config = { };
}
