{ pkgs, ... }: {
  home.packages = with pkgs; [ krita gimp-with-plugins ] ++ (with pkgs.gimpPlugins; [
  ]);
}
