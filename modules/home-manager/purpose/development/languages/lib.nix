{ lib }:
let
  inherit (builtins) filter;
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
    that carry an `enable` field, so this also filters out helper entries.
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

  /*
    Servers that also format.
    Renderers prefer these over external formatters on languages they serve.
  */
  lspFormatters = languages: filter (descriptor: descriptor.providesFormatting) (lsp languages);

  descriptors = languages: (lsp languages) ++ (formatters languages);

  languageNames = import ./names.nix;

  /*
    Canonical language ids for a descriptor.
    Descriptors without explicit languages inherit the owning module name.
  */
  canonicalLanguages =
    descriptor: if descriptor.languages != [ ] then descriptor.languages else [ descriptor.language ];

  /*
    Canonical ids translated to an editor's language names.
    `editors.<name>.languages` stays available as an explicit override.
  */
  editorLanguages =
    editor: descriptor:
    let
      override = (descriptor.editors.${editor} or { }).languages or [ ];
    in
    if override != [ ] then
      override
    else
      map (id: (languageNames.${id}.${editor} or id)) (canonicalLanguages descriptor);

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
    canonicalLanguages
    descriptors
    editorExtensions
    editorLanguages
    enabled
    flatten
    formatters
    lsp
    lspFormatters
    packages
    ;
}
