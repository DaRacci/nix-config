{ pkgs, ... }: {
  imports = [
    ./features/desktop/gnome.nix
    ./features/desktop/hyprland

    ./features/cli
    ../common/features/games
    ../common/applications
  ];

  home.packages = with pkgs.unstable; [ trayscale ];
  user.persistence.enable = true;

  systemd.user.services.autorandr = {
    Unit = {
      Description = "autorandr";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.autorandr}/bin/autorandr --change --force";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

  purpose = {
    development = {
      enable = true;
      rust.enable = true;
    };

    gaming = {
      enable = true;
      osu.enable = true;
      roblox.enable = true;
      steam.enable = true;

      modding = {
        enable = true;
        enableSatisfactory = true;
      };
    };

    modelling = {
      enable = true;
      blender.enable = true;
    };
  };

  programs.autorandr = {
    enable = true;
    profiles = {
      USA = {
        config = {
          DP-4 = {
            enable = true;
            primary = true;

            dpi = 96;
            rate = "164.999";
            mode = "2560x1440";
            position = "1920x1080";
          };

          HDMI-1 = {
            enable = true;

            dpi = 96;
            rate = "74.973";
            mode = "1920x1080";
            position = "2240x0";
          };

          HDMI-2 = {
            enable = true;

            dpi = 96;
            rate = "119.879";
            mode = "1920x1080";
            position = "0x1260";
          };
        };

        fingerprint = {
          DP-4 = "00ffffffffffff004c2d8171585858432f1f0104b53c22783b8cb5af4f43ab260e5054bfef80714f810081c081809500a9c0b300010198e200a0a0a029500840350055502100001a000000fd0030a5f5f543010a202020202020000000fc004f64797373657920473530410a000000ff0048345a524230343038300a2020022002032af144903f1f042309070783010000e305c0006d1a0000020130a5000000000000e6060501615a00565e00a0a0a029503020350055502100001a6fc200a0a0a055503020350055502100001a5a8780a070384d403020350055502100001a023a801871382d40582c450055502100001e00000000000000000000000000797012790000030128a2030188ff099f002f801f009f0528001a000700489600087f079f002f801f00370428001a0007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005c90";
          HDMI-1 = "00ffffffffffff001e6d555b01010101011a010380301b78ea3135a5554ea1260c5054a54b00714f81809500b300a9c0810081c09040023a801871382d40582c4500e00e1100001e000000fd00384b1e5512000a202020202020000000fc004c472046554c4c2048440a2020000000ff000a202020202020202020202020016102031bf14890040301121f1013230907078301000065030c002000023a801871382d40582c4500e00e1100001e2a4480a07038274030203500e00e1100001e011d007251d01e206e285500e00e1100001e8c0ad08a20e02d10103e9600e00e11000018000000000000000000000000000000000000000000000000000000003b";
          HDMI-2 = "00ffffffffffff0005e301271c070200151d0103803c22782a0cc1af4f40ab25145054bfef00d1c081803168317c4568457c6168617c023a801871382d40582c450056502100001efc7e8088703812401820350056502100001e000000fc003237473147340a202020202020000000fd0030901ea01e000a2020202020200102020328f14c101f0514041303120211013f230907078301000065030c001000681a000001013090e6866f80a0703840403020350056502100001efe5b80a0703835403020350056502100001eab22a0a050841a303020360056502100001a7c2e90a0601a1e403020360056502100001a00000000000000000000000000000011";
        };
      };
    };
  };
}
