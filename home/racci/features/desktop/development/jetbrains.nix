{ pkgs, lib, config, ... }: {
  nixpkgs.overlays =
    let
      owner = "Followin";
      branchname = "jetbrains-rust-rover-init"; # branchname or rev
      pkgsReview = pkgs.fetchzip {
        url = "https://github.com/${owner}/nixpkgs/archive/${branchname}.tar.gz";
        # Change to 52 zeroes when the archive needs to be redownloaded
        sha256 = "sha256-gdcoP0yTmFjlQOMoqxFSZnhQf/41fnx2XnQWOReaR7Q=";
      };
    in
    [
      (self: super: {
        # review = import pkgsReview { overlays = [ ]; config = super.config; };
        jetbrains = (import pkgsReview { overlays = [ ]; config = super.config; }).jetbrains;
      })
    ];

  home.packages = with pkgs; [
    jetbrains.idea-community
    jetbrains.rust-rover
  ];

  programs.git = lib.mkIf config.programs.git.enable {
    ignores = [ ".idea" ];
  };

  home.persistence."/persist/home/racci" = {
    directories = [
      ".local/share/JetBrains"
      ".cache/JetBrains" # TODO :: use version from pkg to limit further
      ".config/JetBrains" # Needed?
    ];
  };
}
