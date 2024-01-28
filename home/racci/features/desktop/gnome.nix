{ flake, lib, ... }: {
  imports = [ "${flake}/home/common/desktop/gnome" ];

  dconf.settings = with lib.hm.gvariant; let
    mkLocation = name: short: location: mkVariant [
      (mkUint32 2)
      (mkVariant [
        name
        short
        true
        [ (mkTuple [ location.latitude location.longitude ]) ]
        [ (mkTuple [ location.latitude location.longitude ]) ]
      ])
    ];

    sydney = mkLocation "Sydney" "YSSY" { latitude = -0.592539281052075; longitude = 2.638646934988996; };
  in
  {
    "org/gnome/weather" = {
      locations = [ sydney ];
    };

    "org/gnome/clocks" = {
      world-clocks = [
        sydney
        (mkLocation "Portland" "KPDX" { latitude = 0.795710144576884; longitude = -2.1397785149603687; })
        (mkLocation "Dubai" "OMDB" { latitude = 0.4406956361285682; longitude = 0.9657488469524315; })
      ];
    };
  };
}
