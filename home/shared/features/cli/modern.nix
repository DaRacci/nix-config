{
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      du-dust
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
