{ pkgs, lib, config, ... }: {
  home.packages = with pkgs; [
    idea-community
    # goland
  ];

  programs.git = lib.mkIf config.programs.git.enable {
    ignores = [ ".idea" ];
  };

  home.persistence."/persist/home/racci" = {
    directories = [
      ".local/share/JetBrains"
      ".cache/JetBrains" # TODO :: use version from pkg to limit further
    ];
  };
}