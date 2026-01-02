# This is a special module that will apply the flake module options to each Home-Manager
# users configuration; it is imported by the lib/builders/home/userConf.nix function.
#
# The use of optionalAttrs is important to prevent errors on profiles that don't import these options.
_:
{
  lib,
  ...
}:
let
  inherit (lib) mkMerge;
in
mkMerge [ ]
