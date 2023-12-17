{ config, lib, ... }: with lib; let
  cfg = config.display;

  spec = {
    options = {
      connector = mkOption {
        type = types.str;
        default = "";
      };

      vendorId = mkOption {
        type = types.str;
        default = throw "no vendorId specified for monitor";
      };

      productId = mkOption {
        type = types.str;
        default = throw "no productId specified for monitor";
      };

      serial = mkOption {
        type = types.str;
        default = throw "no serial specified for monitor";
      };
    };
  };

  mode = {
    options = {
      width = mkOption {
        type = with types; int;
        default = 0;
      };

      height = mkOption {
        type = with types; int;
        default = 0;
      };

      refresh = mkOption {
        type = with types; float;
        default = "60";
      };
    };
  };

  relative = {
    options = {
      direction = mkOption {
        type = types.enum [ "left-of" "right-of" "above" "below" ];
        default = "right-of";
      };

      target = mkOption {
        type = types.str;
        default = "";
        description = "The serial of the monitor to position relative to";
      };
    };
  };

  position = {
    options = {
      primary = mkOption {
        type = types.bool;
        default = false;
        description = "Whether this monitor is the primary monitor";
      };

      relative = mkOption {
        default = {
          direction = "right-of";
          target = "";
        };
        description = "Position this monitor relative to another monitor";
        type = types.submodule relative;
      };
    };
  };

  monitor = {
    options = {
      spec = mkOption {
        type = types.submodule spec;
        default = throw "no spec specified for monitor";
      };

      mode = mkOption {
        type = types.submodule mode;
        default = throw "no mode specified for monitor";
      };

      position = mkOption {
        type = types.submodule position;
        default = throw "no position specified for monitor";
      };
    };
  };
in
{
  options.display = {
    enable = mkEnableOption "display";

    monitors = mkOption {
      type = with types; listOf (submodule monitor);
      default = [ ];
    };
  };

  config =
    let
      primaryMonitor = builtins.head (builtins.filter (m: m.position.primary) cfg.monitors);
      # maxResolution = builtins.foldl' (a: b: if a.mode.width > b.mode.width then a else b) (builtins.head cfg.monitors) cfg.monitors;

      # getIndex = monitor: lib.lists.findFirstIndex (m: monitor.spec.serial == m.spec.serial) cfg.monitors;
      # getInfront = monitor:
      #   if (monitor.spec.serial == primaryMonitor.spec.serial) then [ ]
      #   else builtins.filter (m: (getIndex monitor) < (getIndex m)) cfg.monitors;
    in
    mkIf (cfg.enable && (builtins.length cfg.monitors) != 0) {
      assertions = [
        {
          assertion = let monitorSerials = map (m: m.spec.serial) cfg.monitors; in
            (builtins.length (builtins.filter (m: !(builtins.elem m.position.relative.target monitorSerials)) cfg.monitors)) != 0;
          message = "display is disabled";
        }
        {
          assertion = let primaryMonitors = builtins.filter (m: m.position.primary) cfg.monitors; in
            (builtins.length primaryMonitors) == 1 || (builtins.length cfg.monitors) == 1;
          message = "there must be exactly one primary monitor; if there is only one monitor, it is assumed to be primary";
        }
      ];

      # Gnome Display Manager
      home.file.".config/monitors.xml".text =
        let
          getXY = monitor:
            let
              target = builtins.head (builtins.filter (m: m.spec.serial == monitor.position.relative.target || m.spec.productId == monitor.position.relative.target) cfg.monitors);

              beforeXY =
                if primaryMonitor.spec.serial == monitor.position.relative.target
                then { x = 0; y = 0; }
                else getXY target;

              newXY =
                if primaryMonitor.spec.serial == monitor.spec.serial
                then { x = 0; y = 0; }
                else if monitor.position.relative.direction == "left-of" then
                  { x = beforeXY.x - monitor.mode.width; y = beforeXY.y; }
                else if monitor.position.relative.direction == "right-of" then
                  { x = beforeXY.x + target.mode.width; y = beforeXY.y; }
                else if monitor.position.relative.direction == "above" then
                  { x = beforeXY.x; y = beforeXY.y - monitor.mode.height; }
                else if monitor.position.relative.direction == "below" then
                  { x = beforeXY.x; y = beforeXY.y + target.mode.height; }
                else throw "invalid direction";
            in
            newXY;

          mkLogicalMonitor = monitor:
            let inherit (getXY monitor) x y; in
            ''
              <logicalmonitor>
                <x>${toString x}</x>
                <y>${toString y}</y>
                <scale>1</scale>
                <monitor>
                  <monitorspec>
                    ${lib.strings.optionalString (monitor.position.primary) "<primary>yes</primary>"}
                    ${lib.strings.optionalString ((builtins.stringLength monitor.spec.connector) != 0) "<connector>${monitor.spec.connector}</connector>"}
                    <vendor>${monitor.spec.vendorId}</vendor>
                    <product>${monitor.spec.productId}</product>
                    <serial>${monitor.spec.serial}</serial>
                  </monitorspec>
                  <mode>
                    <width>${toString monitor.mode.width}</width>
                    <height>${toString monitor.mode.height}</height>
                    <rate>${toString monitor.mode.refresh}</rate>
                  </mode>
                </monitor>
              </logicalmonitor>
            '';
        in
        ''
          <monitors version="2">
            <configuration>
              ${lib.strings.concatMapStrings (m: mkLogicalMonitor m) cfg.monitors}
            </configuration>
          </monitors>
        '';
    };
}

# programs.autorandr = {
#     enable = true;
#     profiles = {
#       AUS = {
#         config = {
#           DP-0 = {
#             mode = "2560x1440";
#             refresh = "143.912";
#             position = "0x0";
#           };
#           DP-2 = {
#             mode = "2560x1440";
#             refresh = "165.0";
#             position = "2560x0";
#             primary = true;
#           };
#           DP-4 = {
#             mode = "2560x1440";
#             refresh = "143.912";
#             position = "5120x0";
#           };
#         };
#         fingerprint = {
#           DP-0 = "00ffffffffffff0005e3102710000000031b0104a53c22783ba595a65650a0260d5054bfef00d1c081803168317c4568457c6168617c565e00a0a0a029503020350055502100001e40e7006aa0a067500820980455502100001a000000fd001e92e6e63c010a202020202020000000fc0041473237315147340a2020202001d002031ef14b0103051404131f12021190230907078301000065030c00100093be006aa0a055500820980455502100001e409d006aa0a046500820980455502100001e023a801871382d40582c450055502100001eab22a0a050841a303020360055502100001af03c00d051a0355060883a0055502100001c00000000000000ac";
#           DP-2 = "00ffffffffffff0006b3b42752360100081d0104a53d237806ee91a3544c99260f505421080001010101010101010101010101010101565e00a0a0a029503020350060622100001a000000ff002341534e746a4b396764423764000000fd001ea558f040010a202020202020000000fc00524f472050473237560a202020015a020312412309070183010000654b040001015a8700a0a0a03b503020350060622100001a5aa000a0a0a046503020350060622100001a6fc200a0a0a055503020350060622100001a22e50050a0a0675008203a0060622100001e42f80050a0a0135008203a0060622100001e0000000000000000000000000000000000000001";
#           DP-4 = "00ffffffffffff0005e31027aa000000201b0104a53c22783ba595a65650a0260d5054bfef00d1c081803168317c4568457c6168617c565e00a0a0a029503020350055502100001e40e7006aa0a067500820980455502100001a000000fd001e92e6e63c010a202020202020000000fc0041473237315147340a20202020011902031ef14b0103051404131f12021190230907078301000065030c00100093be006aa0a055500820980455502100001e409d006aa0a046500820980455502100001e023a801871382d40582c450055502100001eab22a0a050841a303020360055502100001af03c00d051a0355060883a0055502100001c00000000000000ac";
#         };
#       };
#       USA = {
#         config = {
#           Odyssey-G50A = {
#             mode = "2560x1440";
#             refresh = "164.85";
#             position = "1920x0";
#             primary = true;
#           };
#           LG-FULL-HD = {
#             mode = "1920x1080";
#             refresh = "74.91";
#             position = "0x0";
#           };
#         };
#         fingerprint = { };
#       };
#     };
#   };
