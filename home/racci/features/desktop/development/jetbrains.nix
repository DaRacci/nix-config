{ pkgs, lib, config, ... }: {
  home.packages = with pkgs; [
    jetbrains.idea-community
    unstable.jetbrains.rust-rover
  ];

  programs.git = lib.mkIf config.programs.git.enable {
    ignores = [ ".idea" ];
  };

  user.persistence.directories = [
    ".local/share/JetBrains"
    ".cache/JetBrains" # TODO :: use version from pkg to limit further
    ".config/JetBrains" # Needed?
  ];
}
