{ lib }:
let
  inherit (builtins) filter map;
  inherit (lib)
    concatLists
    filterAttrs
    isAttrs
    mapAttrsToList
    unique
    ;

  /*
    Language configs that are enabled.

    Language modules are the only attrsets under `purpose.development.languages`
    that carry an `enable` option, so this also filters out helper options.
  */
  enabled = languages: filterAttrs (_: value: isAttrs value && (value.enable or false)) languages;

  /*
    Flatten one descriptor field across all enabled languages.

    Each descriptor is annotated with the language that declared it.
  */
  flatten =
    field: languages:
    concatLists (
      mapAttrsToList (
        language: cfg: map (descriptor: descriptor // { inherit language; }) (cfg.${field} or [ ])
      ) (enabled languages)
    );

  lsp = flatten "lsp";
  formatters = flatten "formatters";

  descriptors = languages: (lsp languages) ++ (formatters languages);

  packages =
    languages:
    unique (
      filter (pkg: pkg != null) (map (descriptor: descriptor.package or null) (descriptors languages))
    );

  # Extensions declared by enabled languages for a specific editor.
  editorExtensions =
    editor: languages:
    unique (
      concatLists (mapAttrsToList (_: cfg: cfg.editors.${editor}.extensions or [ ]) (enabled languages))
    );
in
{
  inherit
    descriptors
    editorExtensions
    enabled
    flatten
    formatters
    lsp
    packages
    ;
}
