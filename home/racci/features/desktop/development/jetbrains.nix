{ pkgs, lib, config, ... }: {
  nixpkgs.overlays =
    let
      owner = "DaRacci";
      branchname = "jetbrains-update";
      pkgsReview = pkgs.fetchzip {
        url = "https://github.com/${owner}/nixpkgs/archive/${branchname}.tar.gz";
        # Change to 52 zeroes when the archive needs to be redownloaded
        sha256 = "sha256-M/KzmDbQeFWeuyL0Dj9eu8KAmM9ae78AD5D1FNnDJSE=";
      };
    in
    [
      (self: super: {
        jetbrains = (import pkgsReview { overlays = [ ]; config = super.config; }).jetbrains;
      })
    ];

  home.packages = with pkgs; [
    # jetbrains.idea-community
    jetbrains.rust-rover
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
