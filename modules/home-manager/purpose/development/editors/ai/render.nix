{ lib, languages }:
let
  inherit (lib)
    listToAttrs
    map
    nameValuePair
    optionalAttrs
    recursiveUpdate
    ;

  helpers = import ../../languages/lib.nix { inherit lib; };

  lsp = helpers.lsp languages;
  formatters = helpers.formatters languages;

  binaryName = descriptor: if descriptor.binary != null then descriptor.binary else descriptor.name;

  lspEntry =
    descriptor:
    let
      generated = {
        command = [ (binaryName descriptor) ] ++ descriptor.args;
      }
      // optionalAttrs (descriptor.filetypes != [ ]) {
        extensions = descriptor.filetypes;
      }
      // optionalAttrs (descriptor.env != { }) {
        env = descriptor.env;
      }
      // optionalAttrs (descriptor.initializationOptions != { }) {
        initialization = descriptor.initializationOptions;
      };
    in
    recursiveUpdate generated (descriptor.editors.opencode or { });

  formatterEntry =
    descriptor:
    let
      generated = {
        command = [
          (binaryName descriptor)
          "$FILE"
        ];
      }
      // optionalAttrs (descriptor.filetypes != [ ]) {
        extensions = descriptor.filetypes;
      };
    in
    recursiveUpdate generated (descriptor.editors.opencode or { });
in
{
  packages = helpers.packages languages;

  lsp = listToAttrs (map (descriptor: nameValuePair descriptor.name (lspEntry descriptor)) lsp);

  formatter = listToAttrs (
    map (descriptor: nameValuePair descriptor.name (formatterEntry descriptor)) formatters
  );
}
