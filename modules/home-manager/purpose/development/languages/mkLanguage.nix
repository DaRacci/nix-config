{
  config,
  pkgs,
  lib,

  name,

  treesitterPackage ? null,
  treesitterPackages ? [ ],
  lspPackages ? [ ],
  formatterPackages ? [ ],
  extraPackages ? [ ],

  imports ? [ ],
  options ? { },
  extraConfig ? { },
}:
let
  inherit (lib)
    concatLists
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    optional
    ;
  inherit (types)
    listOf
    package
    ;

  rootCfg = config.purpose.development;
  cfg = config.purpose.development.languages.${name};
in
{
  inherit imports;

  options.purpose.development.languages.${name} = {
    enable = mkEnableOption "Enable language support for ${name}";

    treesitterPackages = mkOption {
      type = listOf package;
      default =
        if treesitterPackages != [ ] then
          treesitterPackages
        else if treesitterPackage != null then
          [ treesitterPackage ]
        else
          (
            let
              pkgName = "tree-sitter-grammars.tree-sitter-${name}";
              pkg = pkgs.${pkgName} or null;
            in
            optional (pkg != null) pkg
          );
      description = ''
        The Tree-sitter grammar package for ${name}, if available.

        By default this will attempt to find a package named tree-sitter-grammars.tree-sitter-${name} and use that if it exists,
        but you can override it here if the package is named differently or if you want to use a custom grammar.
      '';
    };

    lspPackages = mkOption {
      type = listOf package;
      default = lspPackages;
      description = ''
        The LSP server package(s) for ${name}.
        This will be used to provide editor/IDE support for ${name} in supported editors.
      '';
    };

    formatterPackages = mkOption {
      type = listOf package;
      default = formatterPackages;
      description = ''
        The formatter package(s) for ${name}.
        This will be used to provide code formatting support for ${name} in supported editors.
      '';
    };

    extraPackages = mkOption {
      type = listOf package;
      default = extraPackages;
      description = "Additional packages to expose to editors/IDEs for this language.";
    };

    allPackages = mkOption {
      type = listOf package;
      readOnly = true;
      default = concatLists [
        cfg.treesitterPackages
        cfg.lspPackages
        cfg.formatterPackages
        cfg.extraPackages
      ];
      description = "All packages related to ${name}, including Tree-sitter grammar, LSP servers, formatters, and any extra packages.";
    };
  }
  // options;

  config = mkIf (cfg.enable && rootCfg.enable) (mkMerge [
    extraConfig

    {
      programs.zed-editor = {
        extraPackages = cfg.allPackages;
      };
    }
  ]);
}
