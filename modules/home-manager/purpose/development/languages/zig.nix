{
  config,
  pkgs,
  lib,
  ...
}:
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "zig";

  lsp = [
    {
      name = "zls";
      package = pkgs.zls;
      filetypes = [ ".zig" ];
    }
  ];

  extraPackages = [ pkgs.zig ];

  editors = {
    zed.extensions = [ "zig" ];
    vscode = {
      profile = "default";
      extensions = [ "ziglang.vscode-zig" ];
    };
  };
}
