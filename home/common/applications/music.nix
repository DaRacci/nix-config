{ pkgs, ... }: {
  nixpkgs.overlays = [
    (self: super: {
      spotube = (import
        (pkgs.fetchzip (
          let owner = "TomaSajt"; branch = "spotube-bin"; in {
            url = "https://github.com/${owner}/nixpkgs/archive/${branch}.tar.gz";
            # Change to 52 zeros when archive needs to be redownloaded.
            sha256 = "sha256-pt6TPweB7dW+sLY0rnPBJIUETkF6T/EIkW1/zPPMHWY=";
          }
        ))
        { overlays = [ ]; config = super.config; }).spotube;
    })
  ];

  home.packages = with pkgs; [ spotube ];
}
