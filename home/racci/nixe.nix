{ pkgs, ... }: {
  imports = [
    ./features/desktop/gnome

    ./features/cli
    ../common/features/games
    ./features/desktop/development
    ../common/applications
  ];

  home.packages = with pkgs.unstable; [ trayscale ];
  user.persistence.enable = true;

  display = {
    enable = true;

    monitors = [
      {
        spec = {
          vendorId = "SAM";
          productId = "Odyssey-G50A";
          serial = "H4ZRB04080";
        };

        mode = {
          width = 2560;
          height = 1440;
          refresh = 164.999;
        };

        position.primary = true;
      }
      {
        spec = {
          vendorId = "LG";
          productId = "LG FULL HD";
          serial = "0x01010101";
        };

        mode = {
          width = 1920;
          height = 1080;
          refresh = 74.973;
        };

        position.relative = {
          direction = "above";
          target = "Odyssey-G50A";
        };
      }
      {
        spec = {
          vendorId = "AOC";
          productId = "27G1G4";
          serial = "0x0002071c";
        };

        mode = {
          width = 1920;
          height = 1080;
          refresh = 119.879;
        };

        position.relative = {
          direction = "left-of";
          target = "Odyssey-G50A";
        };
      }
    ];
  };
}
