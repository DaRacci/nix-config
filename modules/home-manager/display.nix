{ config, lib, ... }: with lib; let
  cfg = config.display;

  monitor = {
    # spec = {
    #   connector = mkOption {
    #     type = types.str;
    #     default = null;
    #   };

    #   vendorId = mkOption {
    #     type = types.str;
    #     default = throw "no vendorId specified for monitor";
    #   };

    #   productId = mkOption {
    #     type = types.str;
    #     default = throw "no productId specified for monitor";
    #   };

    #   serial = mkOption {
    #     type = types.str;
    #     default = throw "no serial specified for monitor";
    #   };
    # };

    # mode = {
    #   width = mkOption {
    #     type = types.str;
    #     default = throw "no resolution specified for monitor";
    #   };

    #   height = mkOption {
    #     type = types.str;
    #     default = throw "no resolution specified for monitor";
    #   };

    #   refresh = mkOption {
    #     type = types.str;
    #     default = "60";
    #   };
    # };

    # position = {
    #   primary = mkOption {
    #     type = types.bool;
    #     default = false;
    #     description = "Whether this monitor is the primary monitor";
    #   };

    #   relative = {
    #     direction = mkOption {
    #       type = types.enum [ "left-of" "right-of" "above" "below" ];
    #       default = throw "no direction specified for relative position";
    #     };

    #     target = mkOption {
    #       type = types.str;
    #       default = throw "no monitor specified for relative position";
    #       description = "The serial of the monitor to position relative to";
    #     };
    #   };
    # };
  };
in
{
  options.display = {
    enable = mkEnableOption "display";

    monitors = mkOption {
      type = types.listOf monitor;
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
    mkIf (cfg.enable && cfg.monitors != [ ]) {
      # assertions = [
      #   {
      #     assertion = let monitorSerials = map (m: m.spec.serial) cfg.monitors; in
      #       lib.isEmpty (builtins.filter (m: !(builtins.elem m.position.relativeTo.monitor monitorSerials)) cfg.monitors);
      #     message = "display is disabled";
      #   }
      #   {
      #     assertion = let primaryMonitors = builtins.filter (m: m.position.primary) cfg.monitors; in
      #       length primaryMonitors == 1 || length cfg.monitors == 1;
      #     message = "there must be exactly one primary monitor; if there is only one monitor, it is assumed to be primary";
      #   }
      # ];

      # Gnome Display Manager
      home.file.".config/monitors.xml".text =
        let
          getXY = monitor:
            let
              target = builtins.head (builtins.filter (m: m.spec.serial == monitor.position.relative.target) cfg.monitors);

              beforeXY =
                if primaryMonitor.spec.serial == monitor.position.relative.target
                then { x = 0; y = 0; }
                else getXY target;

              newXY =
                if monitor.position.relative.direction == "left-of" then
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
                <x>${x}</x>
                <y>${y}</y>
                <scale>1</scale>
                <monitor>
                  <monitorspec>
                    ${optional (monitor.position.primary) "<primary>yes</primary>"}
                    ${optional (monitor.spec.connector != null) "<connector>${monitor.spec.connector}</connector>"}
                    <vendor>${monitor.spec.vendorId}</vendor>
                    <product>${monitor.spec.productId}</product>
                    <serial>${monitor.spec.serial}</serial>
                  </monitorspec>
                  <mode>
                    <width>${monitor.mode.width}</width>
                    <height>${monitor.mode.height}</height>
                    <rate>${monitor.mode.refresh}</rate>
                  </mode>
                </monitor>
              </logicalmonitor>
            '';
        in
        ''
          <monitors version="2">
            <configuration>

            </configuration>
          </monitors>
        '';
    };
}
