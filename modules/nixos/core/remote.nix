{
  config,
  options,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    getExe
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optionalAttrs
    ;
  inherit (lib.types) str submodule;

  sunshine-proxy-wrapper = pkgs.writeShellScript "sunshine-proxy-wrapper" ''
    set -euo pipefail
    systemctl --user start sunshine.service
    port=47989
    ss_bin=${pkgs.iproute2}/bin/ss
    proxy_bin=${pkgs.systemd}/lib/systemd/systemd-socket-proxyd
    for i in $(seq 30); do
      $ss_bin -Htlnp "sport = :$port" 2>/dev/null | grep -q . && { exec $proxy_bin --exit-idle-time=300s 127.0.0.1:$port; }
      sleep 0.5
    done
    exec $proxy_bin --exit-idle-time=300s 127.0.0.1:$port
  '';

  cfg = config.core.remote;
  hasHomeManager = options ? home-manager;
in
{
  options.core.remote = {
    enable = mkEnableOption "remote features";

    remoteDesktop = mkOption {
      default = { };
      type = submodule {
        options = {
          enable = mkEnableOption "remote desktop";

          startCommand = mkOption {
            type = str;
            default = "gnome-session";
            description = "Command to start remote desktop session.";
          };
        };
      };
    };

    streaming = mkOption {
      default = { };
      type = submodule {
        options = {
          enable = mkEnableOption "remote streaming";
        };
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.remoteDesktop.enable {
      services.xrdp = {
        enable = true;
        defaultWindowManager = cfg.remoteDesktop.startCommand;
        openFirewall = true;
      };
    })

    (mkIf cfg.streaming.enable (
      {
        services.sunshine = {
          enable = true;
          autoStart = false;
          openFirewall = true;
          capSysAdmin = true;
        };

        networking.firewall = {
          extraCommands = ''
            iptables -t nat -A PREROUTING -p tcp --dport 47989 -j REDIRECT --to-port 48989
            ip6tables -t nat -A PREROUTING -p tcp --dport 47989 -j REDIRECT --to-port 48989
            iptables -A nixos-fw -p tcp --dport 48989 -m conntrack --ctorigdstport 47989 -j nixos-fw-accept
            ip6tables -A nixos-fw -p tcp --dport 48989 -m conntrack --ctorigdstport 47989 -j nixos-fw-accept
          '';
          extraStopCommands = ''
            iptables -t nat -D PREROUTING -p tcp --dport 47989 -j REDIRECT --to-port 48989 || true
            ip6tables -t nat -D PREROUTING -p tcp --dport 47989 -j REDIRECT --to-port 48989 || true
            iptables -D nixos-fw -p tcp --dport 48989 -m conntrack --ctorigdstport 47989 -j nixos-fw-accept || true
            ip6tables -D nixos-fw -p tcp --dport 48989 -m conntrack --ctorigdstport 47989 -j nixos-fw-accept || true
          '';
        };

        systemd.user.sockets.sunshine-proxy = {
          wantedBy = [ "sockets.target" ];
          socketConfig = {
            ListenStream = "48989";
          };
        };

        systemd.user.services.sunshine-proxy = {
          requires = [ "sunshine.service" ];
          bindsTo = [
            "sunshine.service"
            "sunshine-proxy.socket"
          ];
          after = [
            "sunshine.service"
            "sunshine-proxy.socket"
          ];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${sunshine-proxy-wrapper}";
            Restart = "no";
          };
        };

        systemd.user.services.sunshine = {
          wantedBy = lib.mkForce [ ];
          partOf = lib.mkForce [ ];
          unitConfig.StopWhenUnneeded = true;
          serviceConfig.Restart = lib.mkForce "no";
        };
      }
      // optionalAttrs hasHomeManager {
        home-manager.sharedModules = [
          {
            user.persistence.directories = [ ".config/sunshine" ];
          }
        ];
      }
    ))

    # TODO:Why headless-2 and not headless-1, cant remember, need to test.
    (mkIf (cfg.streaming.enable && config.programs.hyprland.enable) (
      {
        services.sunshine = {
          settings.output_name = "3";
          applications.apps = [
            {
              name = "Shared Desktop";
              prep-cmd = [
                {
                  do = ''sh -c "hyprctl keyword monitor HEADLESS-2,''${SUNSHINE_CLIENT_WIDTH}x''${SUNSHINE_CLIENT_HEIGHT}@''${SUNSHINE_CLIENT_FPS},auto,1"'';
                  undo = "hyprctl keyword monitor HEADLESS-2,disable";
                }
              ];
            }
            {
              name = "Exclusive Desktop";
              prep-cmd = [
                {
                  do = ''sh -c "hyprctl keyword monitor HEADLESS-2,''${SUNSHINE_CLIENT_WIDTH}x''${SUNSHINE_CLIENT_HEIGHT}@''${SUNSHINE_CLIENT_FPS},auto,1" && sleep 5'';
                  undo = "hyprctl keyword monitor HEADLESS-2,disable";
                }
                (
                  let
                    doScript = pkgs.writeShellApplication {
                      name = "hyprland-disable-other-monitors-pre-sunshine";
                      runtimeInputs = [
                        pkgs.hyprland
                        pkgs.jq
                      ];
                      text = ''
                        OUTPUT_FILE="$XDG_STATE_HOME/hyprland-disabled-monitors-pre-sunshine.json"
                        ENABLED_MONITORS=$(hyprctl -j monitors | jq '. - map(select((.name | contains("HEADLESS")) or .disabled == true))')
                        echo "$ENABLED_MONITORS" > "$OUTPUT_FILE"

                        for monitor in $(echo "$ENABLED_MONITORS" | jq -r '.[].name'); do
                          hyprctl keyword monitor "$monitor,disable"
                        done
                      '';
                    };

                    undoScript = pkgs.writeShellApplication {
                      name = "hyprland-restore-disabled-monitors-post-sunshine";
                      runtimeInputs = [
                        pkgs.hyprland
                        pkgs.jq
                      ];
                      text = ''
                        INPUT_FILE="$XDG_STATE_HOME/hyprland-disabled-monitors-pre-sunshine.json"
                        if [ -f "$INPUT_FILE" ]; then
                          for monitor in $(jq -r '.[].name' < "$INPUT_FILE"); do
                            hyprctl keyword monitor "$monitor,enable"
                          done
                          rm "$INPUT_FILE"
                        fi
                      '';
                    };
                  in
                  {
                    do = "sh -c '${getExe doScript}'";
                    undo = "sh -c '${getExe undoScript}'";
                  }
                )
              ];
            }
          ];
        };
      }
      // optionalAttrs hasHomeManager {
        home-manager.sharedModules = [
          {
            wayland.windowManager.hyprland = {
              custom-settings.permission.screenCopy = [ (lib.getExe pkgs.sunshine) ];
              settings = {
                on = [
                  {
                    _args = [
                      "hyprland.start"
                      (lib.generators.mkLuaInline "function() hl.exec_cmd('hyprctl output create headless') end")
                    ];
                  }
                ];
                monitor = [
                  {
                    output = "HEADLESS-2";
                    disabled = true;
                  }
                ];
              };
            };
          }
        ];
      }
    ))
  ]);
}
