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
  lspFormatters = helpers.lspFormatters languages;

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

  lspFormats =
    language:
    let
      matches = filter (descriptor: builtins.elem language (helixLanguages descriptor)) lspFormatters;
    in
    matches != [ ];

  languageEntry =
    language:
    let
      languageFormatters = filter (
        descriptor: builtins.elem language (helixLanguages descriptor)
      ) formatters;
      languageServers = filter (descriptor: builtins.elem language (helixLanguages descriptor)) lsp;

      # A formatting server wins over an external formatter,
      # and Helix formats with the server when no formatter is set.
      formatter =
        if lspFormats language then
          null
        else if languageFormatters != [ ] then
          formatterEntry (builtins.head languageFormatters)
        else
          null;
    in
    {
      name = language;
    }
    // optionalAttrs (languageServers != [ ]) {
      "language-servers" = map (descriptor: descriptor.name) languageServers;
    }
    // optionalAttrs (lspFormats language || formatter != null) {
      auto-format = true;
    }
    // optionalAttrs (formatter != null) {
      inherit formatter;
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
