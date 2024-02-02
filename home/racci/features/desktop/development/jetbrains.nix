{ pkgs, lib, config, ... }: {
  nixpkgs.overlays =
    let
      owner = "ners";
      branchname = "jetbrains";
      pkgsReview = pkgs.fetchzip {
        url = "https://github.com/${owner}/nixpkgs/archive/${branchname}.tar.gz";
        # Change to 52 zeroes when the archive needs to be redownloaded
        sha256 = "sha256-L1Z3WLN00TLIOU95wqoVdkP38shMxfhzpDxoBv3Gzck=";
      };
    in
    [
      (self: super: {
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

  user.persistence.directories = [
    ".local/share/JetBrains"
    ".cache/JetBrains" # TODO :: use version from pkg to limit further
    ".config/JetBrains" # Needed?
  ];
}
