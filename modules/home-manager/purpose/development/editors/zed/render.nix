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

  /*
    Zed language names for a descriptor.

    Descriptors may target several Zed languages (for example a shared config
    server). Otherwise fall back to the metadata declared by the owning module.
  */
  zedLanguages =
    descriptor:
    if descriptor.languages != [ ] then
      descriptor.languages
    else
      let
        editorConfig = (languages.${descriptor.language}.editors or { }).zed or { };
      in
      editorConfig.languages or [ descriptor.language ];

  allZedLanguages = unique (concatLists (map zedLanguages (lsp ++ formatters)));

  binaryArguments =
    descriptor:
    optionalAttrs (descriptor.args != [ ]) {
      binary.arguments = descriptor.args;
    }
    // optionalAttrs (descriptor.env != { }) {
      binary.env = descriptor.env;
    };

  lspEntry =
    descriptor:
    let
      generated =
        optionalAttrs (descriptor.initializationOptions != { }) {
          initialization_options = descriptor.initializationOptions;
        }
        // optionalAttrs (descriptor.settings != { }) {
          settings = descriptor.settings;
        }
        // binaryArguments descriptor;
      override = removeAttrs (descriptor.editors.zed or { }) [ "languages" ];
    in
    recursiveUpdate generated override;

  serversFor =
    language:
    map (descriptor: descriptor.name) (
      filter (descriptor: builtins.elem language (zedLanguages descriptor)) lsp
    );

  formatterFor =
    descriptor:
    if (descriptor.editors.zed or { }) ? formatter then
      descriptor.editors.zed.formatter
    else
      {
        external = {
          command = binaryName descriptor;
          arguments = descriptor.args;
        };
      };

  formatterValue =
    descriptors:
    if builtins.length descriptors == 1 then
      formatterFor (builtins.head descriptors)
    else
      map formatterFor descriptors;

  languageEntry =
    language:
    let
      languageFormatters = filter (
        descriptor: builtins.elem language (zedLanguages descriptor)
      ) formatters;
    in
    {
      language_servers = serversFor language;
    }
    // optionalAttrs (languageFormatters != [ ]) {
      format_on_save = "on";
      formatter = formatterValue languageFormatters;
    };
in
{
  extraPackages = unique (
    concatLists (map (language: language.allPackages) (attrValues (helpers.enabled languages)))
  );

  extensions = helpers.editorExtensions "zed" languages;

  userSettings = {
    lsp = listToAttrs (map (descriptor: nameValuePair descriptor.name (lspEntry descriptor)) lsp);
    languages = listToAttrs (
      map (language: nameValuePair language (languageEntry language)) allZedLanguages
    );
  };
}
