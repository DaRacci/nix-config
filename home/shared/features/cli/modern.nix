{
  pkgs,
  ...
}:
let
  inherit (pkgs)
    duf
    dust
    gping
    sd
    xh
    ;
in
{
  home = {
    packages = [
      dust
      duf
      gping
      sd
      xh
    ];

    shellAliases = {
      cat = "bat";
      grep = "rg";
      ping = "gping";
    };
  };

  programs = {
    bat.enable = true;
    fd.enable = true;
    ripgrep.enable = true;
  };
}
