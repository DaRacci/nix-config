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

  lsp ? [ ],
  formatters ? [ ],
  editors ? { },

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
    attrs
    listOf
    nullOr
    package
    str
    ;

  rootCfg = config.purpose.development;
  cfg = config.purpose.development.languages.${name};

  descriptorType = types.submodule {
    options = {
      name = mkOption {
        type = str;
        description = "Editor-facing identifier for the server or formatter.";
      };

      package = mkOption {
        type = nullOr package;
        default = null;
        description = ''
          Package providing the binary.
          Leave null for tools the editor resolves or ships itself.
        '';
      };

      binary = mkOption {
        type = nullOr str;
        default = null;
        description = "Binary name resolved from PATH. Defaults to `name`.";
      };

      args = mkOption {
        type = listOf str;
        default = [ ];
        description = "Arguments passed when launching the server or formatter.";
      };

      filetypes = mkOption {
        type = listOf str;
        default = [ ];
        description = "File extensions or globs this descriptor applies to.";
      };

      languages = mkOption {
        type = listOf str;
        default = [ ];
        description = "Editor language identifiers when they differ from the module name.";
      };

      initializationOptions = mkOption {
        type = attrs;
        default = { };
        description = "LSP initialization options.";
      };

      settings = mkOption {
        type = attrs;
        default = { };
        description = "Runtime LSP settings.";
      };

      env = mkOption {
        type = attrs;
        default = { };
        description = "Environment variables for the server process.";
      };

      editors = mkOption {
        type = attrs;
        default = { };
        description = "Per-editor overrides, keyed by editor name.";
      };
    };
  };
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

    lsp = mkOption {
      type = listOf descriptorType;
      default = lsp;
      description = "LSP server descriptors for ${name}.";
    };

    formatters = mkOption {
      type = listOf descriptorType;
      default = formatters;
      description = "Formatter descriptors for ${name}.";
    };

    editors = mkOption {
      type = attrs;
      default = editors;
      description = "Language-level editor metadata, such as extension names.";
    };

    allPackages = mkOption {
      type = listOf package;
      readOnly = true;
      default = concatLists [
        cfg.treesitterPackages
        cfg.lspPackages
        cfg.formatterPackages
        (map (descriptor: descriptor.package) (
          builtins.filter (descriptor: descriptor.package != null) (cfg.lsp ++ cfg.formatters)
        ))
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
