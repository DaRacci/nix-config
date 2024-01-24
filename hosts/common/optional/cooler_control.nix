{ pkgs, ... }: {
  nixpkgs.overlays =
    let
      owner = "codifryed";
      branchname = "coolercontrol-0.17.0"; # branchname or rev
      pkgsReview = pkgs.fetchzip {
        url = "https://github.com/${owner}/nixpkgs/archive/${branchname}.tar.gz";
        # Change to 52 zeroes when the archive needs to be redownloaded
        sha256 = "sha256-IJ/U2sof3PVhkeXQzNoDS8PRFdgl2/5s8ZGgJt7ANps=";
      };
    in
    [
      (self: super: {
        coolercontrol = (import pkgsReview { overlays = [ ]; config = super.config; }).coolercontrol;
      })
    ];

  systemd = {
    packages = with pkgs.coolercontrol; [
      coolercontrol-liqctld
      coolercontrold
    ];
    services = {
      coolercontrol-liqctld.wantedBy = [ "multi-user.target" ];
      coolercontrold.wantedBy = [ "multi-user.target" ];
    };
  };

  host.persistence.directories = [
    "/etc/coolercontrol"
  ];
}
