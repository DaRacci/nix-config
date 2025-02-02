{ pkgs, ... }:
{
  home.packages = with pkgs; [
    (obsidian.override {
      commandLineArgs = "--disable-gpu-compositing";
    })
  ];

  user.persistence.directories = [ ".config/obsidian" ];
}
