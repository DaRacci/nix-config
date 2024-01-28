{ flake, pkgs, ... }:
let inherit (pkgs) lib; in {
  imports = [ "${flake}/home/common/desktop/gnome" ];

  dconf.settings = with lib.hm.gvariant; {
    "org/gnome/Weather" = {
      locations = [ (mkVariant [ (mkUint32 2) (mkVariant [ "Sydney" "YSSY" true [ (mkTuple [ (-0.592539281052075) 2.638646934988996 ]) ] [ (mkTuple [ (-0.5913757223996479) 2.639228723041856 ]) ] ]) ]) ];
    };

    "org/gnome/clocks" = {
      world-clocks = [
        {
          location = mkVariant [ (mkUint32 2) (mkVariant [ "Sydney" "YSSY" true [ (mkTuple [ (-0.592539281052075) 2.638646934988996 ]) ] [ (mkTuple [ (-0.5913757223996479) 2.639228723041856 ]) ] ]) ];
        }
        {
          location = mkVariant [ (mkUint32 2) (mkVariant [ "Portland" "KPDX" true [ (mkTuple [ 0.795710144576884 (-2.1397785149603687) ]) ] [ (mkTuple [ 0.7945341242735976 (-2.1411037260081156) ]) ] ]) ];
        }
        {
          location = mkVariant [ (mkUint32 2) (mkVariant [ "Dubai" "OMDB" true [ (mkTuple [ 0.4406956361285682 0.9657488469524315 ]) ] [ (mkTuple [ 0.4407344173445475 0.9648180105024653 ]) ] ]) ];
        }
      ];
    };
  };
}
