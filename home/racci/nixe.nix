{
  imports = [
    ./features/desktop/gnome
    ./features/desktop/hyprland

    ./features/cli
    ../common/features/games
    ./features/desktop/development
    ../common/applications/obs.nix
    ../common/applications/gimp.nix
  ];

  programs.autorandr = {
    enable = true;
    profiles = {
      AUS = {
        config = {
          DP-0 = {
            mode = "2560x1440";
            rate = "143.912";
            position = "0x0";
          };
          DP-2 = {
            mode = "2560x1440";
            rate = "165.0";
            position = "2560x0";
            primary = true;
          };
          DP-4 = {
            mode = "2560x1440";
            rate = "143.912";
            position = "5120x0";
          };
        };
        fingerprint = {
          DP-0 = "00ffffffffffff0005e3102710000000031b0104a53c22783ba595a65650a0260d5054bfef00d1c081803168317c4568457c6168617c565e00a0a0a029503020350055502100001e40e7006aa0a067500820980455502100001a000000fd001e92e6e63c010a202020202020000000fc0041473237315147340a2020202001d002031ef14b0103051404131f12021190230907078301000065030c00100093be006aa0a055500820980455502100001e409d006aa0a046500820980455502100001e023a801871382d40582c450055502100001eab22a0a050841a303020360055502100001af03c00d051a0355060883a0055502100001c00000000000000ac";
          DP-2 = "00ffffffffffff0006b3b42752360100081d0104a53d237806ee91a3544c99260f505421080001010101010101010101010101010101565e00a0a0a029503020350060622100001a000000ff002341534e746a4b396764423764000000fd001ea558f040010a202020202020000000fc00524f472050473237560a202020015a020312412309070183010000654b040001015a8700a0a0a03b503020350060622100001a5aa000a0a0a046503020350060622100001a6fc200a0a0a055503020350060622100001a22e50050a0a0675008203a0060622100001e42f80050a0a0135008203a0060622100001e0000000000000000000000000000000000000001";
          DP-4 = "00ffffffffffff0005e31027aa000000201b0104a53c22783ba595a65650a0260d5054bfef00d1c081803168317c4568457c6168617c565e00a0a0a029503020350055502100001e40e7006aa0a067500820980455502100001a000000fd001e92e6e63c010a202020202020000000fc0041473237315147340a20202020011902031ef14b0103051404131f12021190230907078301000065030c00100093be006aa0a055500820980455502100001e409d006aa0a046500820980455502100001e023a801871382d40582c450055502100001eab22a0a050841a303020360055502100001af03c00d051a0355060883a0055502100001c00000000000000ac";
        };
      };
    };
  };

  services.autorandr.enable = true;
}
