# This is a special module that will apply the flake module options to each NixOS
# system configuration; it is imported by the lib/builders/mkSystem.nix function.
#
# The use of optionalAttrs is important to prevent errors on systems that don't import these options.
{
  allocations,
  deviceType,
  ...
}:
{
  lib,
  ...
}:
let
  inherit (lib) optionalAttrs mkMerge;
in
mkMerge [
  (optionalAttrs (deviceType == "server") {
    server = {
      ioPrimaryHost = allocations.server.ioPrimaryCoordinator;
      distributedBuilder.builders = allocations.server.distributedBuilders;
    };
  })
]
