{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    ;

  cfg = config.purpose.development.languages.rust;
in
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "rust";

  extraPackages = [ pkgs.cargo pkgs.clippy pkgs.rustc ];
  lspPackages = [ pkgs.rust-analyzer ];
  formatterPackages = [ pkgs.rustfmt ];

  options = {
    rust-rover.enable = mkEnableOption "Add the rust-rover package.";
  };

  extraConfig = {
    home.packages = mkIf cfg.rust-rover.enable [ pkgs.jetbrains.rust-rover ];

    programs.zed-editor = {
      extensions = [ "cargo-tom" ];
    };
  };
}
