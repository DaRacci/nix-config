{ pkgs, lib, config, persistenceDirectory, hasPersistence, ... }: {
  home.packages = with pkgs; [
    jetbrains.idea-community
    unstable.jetbrains.rust-rover
  ];

  programs.git = lib.mkIf config.programs.git.enable {
    ignores = [ ".idea" ];
  };
} // lib.optionalAttrs (hasPersistence) {
  home.persistence."${persistenceDirectory}" = {
    directories = [
      ".local/share/JetBrains"
      ".cache/JetBrains" # TODO :: use version from pkg to limit further
      ".config/JetBrains" # Needed?
    ];
  };
}
