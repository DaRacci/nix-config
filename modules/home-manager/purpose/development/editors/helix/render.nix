{ lib, languages }:
let
  inherit (lib)
    attrValues
    concatLists
    filter
    listToAttrs
    nameValuePair
    optionalAttrs
    recursiveUpdate
    unique
    ;

  helpers = import ../../languages/lib.nix { inherit lib; };

  lsp = helpers.lsp languages;
  formatters = helpers.formatters languages;

  binaryName = descriptor: if descriptor.binary != null then descriptor.binary else descriptor.name;

  helixLanguages = helpers.editorLanguages "helix";

  allHelixLanguages = unique (concatLists (map helixLanguages (lsp ++ formatters)));

  serverEntry =
    descriptor:
    let
      generated = {
        command = binaryName descriptor;
      }
      // optionalAttrs (descriptor.args != [ ]) { args = descriptor.args; }
      // optionalAttrs (descriptor.env != { }) { environment = descriptor.env; };
      override = removeAttrs (descriptor.editors.helix or { }) [
        "formatter"
        "languages"
      ];
    in
    recursiveUpdate generated override;

  formatterEntry =
    descriptor:
    if (descriptor.editors.helix or { }) ? formatter then
      descriptor.editors.helix.formatter
    else
      {
        command = binaryName descriptor;
      }
      // optionalAttrs (descriptor.args != [ ]) { args = descriptor.args; };

  languageEntry =
    language:
    let
      languageFormatters = filter (
        descriptor: builtins.elem language (helixLanguages descriptor)
      ) formatters;
      languageServers = filter (descriptor: builtins.elem language (helixLanguages descriptor)) lsp;
    in
    {
      name = language;
    }
    // optionalAttrs (languageServers != [ ]) {
      "language-servers" = map (descriptor: descriptor.name) languageServers;
    }
    // optionalAttrs (languageFormatters != [ ]) {
      auto-format = true;
      formatter = formatterEntry (builtins.head languageFormatters);
    };
in
{
  extraPackages = unique (
    concatLists (map (language: language.allPackages) (attrValues (helpers.enabled languages)))
  );

  settings.languages = {
    language = map languageEntry allHelixLanguages;
    language-server = listToAttrs (
      map (descriptor: nameValuePair descriptor.name (serverEntry descriptor)) lsp
    );
  };
}
