{ pkgs, lib, config, ... }: {
  home.packages = with pkgs.jetbrains; [
    idea-community
    goland
  ];

  programs.git = lib.mkIf config.programs.git.enable {
    ignores = [ ".idea" ];
  };

  home.persistence."/persist/home/racci" = {
    directories = [ ".local/share/JetBrains" ];
  };
}