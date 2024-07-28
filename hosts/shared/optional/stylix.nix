{ inputs, pkgs, ... }: {
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  stylix = {
    enable = true;
    # Image is needed for now, until https://github.com/danth/stylix/issues/200 is fixed.
    image = pkgs.fetchurl {
      url = "https://initiate.alphacoders.com/images/131/cropped-5120-2880-1319907.jpeg";
      sha256 = "sha256-0sTnxz+R7sgrSq98ng7drdZLHwDsb5B9I3eQUfjiP7E=";
    };
  };
}
