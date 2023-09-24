{ pkgs, ... }: {
  nixpkgs.overlays =
    let
      owner = "codifryed";
      branchname = "coolercontrol-0.17.0"; # branchname or rev
      pkgsReview = pkgs.fetchzip {
        url = "https://github.com/${owner}/nixpkgs/archive/${branchname}.tar.gz";
        # Change to 52 zeroes when the archive needs to be redownloaded
        sha256 = "sha256-Gu99bJfLNLB2X5Gn99JqjNR8I6n305y/7fPRpb5o+xQ=";
      };
    in
    [
      (self: super: {
        coolercontrol = (import pkgsReview { overlays = [ ]; config = super.config; }).coolercontrol;
      })
    ];

  environment.systemPackages = with pkgs; [ lm_sensors ];

  systemd = {
    packages = with pkgs.coolercontrol;
      [
        coolercontrol-liqctld
        coolercontrold
      ];
    services = {
      coolercontrol-liqctld.wantedBy = [ "multi-user.target" ];
      coolercontrold.wantedBy = [ "multi-user.target" ];
    };
  };

  environment.persistence."/persist".directories = [
    "/etc/coolercontrol"
  ];
}
