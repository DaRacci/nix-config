{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.purpose.development.languages.rust;
in
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "rust";

  lsp = [
    {
      name = "rust-analyzer";
      package = pkgs.rust-analyzer;
      filetypes = [ ".rs" ];
    }
  ];

  formatters = [
    {
      name = "rustfmt";
      package = pkgs.rustfmt;
      args = [
        "--emit"
        "stdout"
      ];
      filetypes = [ ".rs" ];
    }
  ];

  extraPackages = [
    pkgs.cargo
    pkgs.clippy
    pkgs.rustc
  ];

  editors = {
    zed = {
      extensions = [ "cargo-tom" ];
      languages = [ "Rust" ];
    };

    helix.languages = [ "rust" ];

    vscode = {
      profile = "rust";
      extensions = [
        "jscearcy.rust-doc-viewer"
        "dustypomerleau.rust-syntax"
        "rust-lang.rust-analyzer"
      ];
    };
  };

  options = {
    rust-rover.enable = mkEnableOption "Add the rust-rover package.";
  };

  extraConfig = {
    home.packages = mkIf cfg.rust-rover.enable [ pkgs.jetbrains.rust-rover ];
  };
}
