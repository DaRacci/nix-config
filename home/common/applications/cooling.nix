{ pkgs, ... }: {
  nixpkgs.overlays =
    let
      owner = "codifryed";
      branchname = "coolercontrol-0.17.0"; # branchname or rev
      pkgsReview = pkgs.fetchzip {
        url = "https://github.com/${owner}/nixpkgs/archive/${branchname}.tar.gz";
        # Change to 52 zeroes when the archive needs to be redownloaded
        sha256 = "sha256-AKAIYAvo60wqKbOYwnUI7Q9IIVTcA1zYWow85zeqf4o=";
      };
    in
    [
      (self: super: {
        # review = import pkgsReview { overlays = [ ]; config = super.config; };
        coolercontrol = (import pkgsReview { overlays = [ ]; config = super.config; }).coolercontrol;
      })
    ];

  home.packages = with pkgs.coolercontrol; [ coolercontrol-gui ];
}
