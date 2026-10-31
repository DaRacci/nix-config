{
  config,
  options,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    attrsToLuaInlineArgs
    getExe'
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optionalAttrs
    ;
  inherit (lib.types) str submodule;

  sunshineProxyWrapper = getExe' pkgs.sunshine-tools "sunshine-proxy-wrapper";
  hyprlandDisableOtherMonitorsPreSunshine = getExe' pkgs.sunshine-tools "hyprland-disable-other-monitors-pre-sunshine";
  hyprlandRestoreDisabledMonitorsPostSunshine = getExe' pkgs.sunshine-tools "hyprland-restore-disabled-monitors-post-sunshine";

  cfg = config.core.remote;
  hasHomeManager = options ? home-manager;

  doUndoHeadlessDisplay = {
    do = ''sh -c "hyprctl keyword monitor HEADLESS-1,''${SUNSHINE_CLIENT_WIDTH}x''${SUNSHINE_CLIENT_HEIGHT}@''${SUNSHINE_CLIENT_FPS},auto,1 && sleep 5"'';
    undo = "hyprctl keyword monitor HEADLESS-1,disable";
  };
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

        networking = {
          firewall.extraInputRules = ''
            meta l4proto tcp ct original proto-dst 47989 tcp dport 48989 accept
          '';

          # The redirect lives in its own table: the nftables module owns and
          # rebuilds every declared table, so there is nothing to delete by hand.
          nftables.tables = {
            sunshine-redirect4 = {
              family = "ip";
              content = ''
                chain prerouting {
                  type nat hook prerouting priority dstnat; policy accept;
                  meta l4proto tcp fib daddr type local tcp dport 47989 redirect to :48989
                }
              '';
            };

            sunshine-redirect6 = {
              family = "ip6";
              content = ''
                chain prerouting {
                  type nat hook prerouting priority dstnat; policy accept;
                  meta l4proto tcp fib daddr type local tcp dport 47989 redirect to :48989
                }
              '';
            };
          };
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
            ExecStart = sunshineProxyWrapper;
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

    (mkIf (cfg.streaming.enable && config.programs.hyprland.enable) (
      {
        services.sunshine = {
          # FIXME: this is a guess and is likely wrong.
          # Should be set to the monitor that is used for the Sunshine client, but we don't know which one that is.
          # Maybe we can guess it based on how many monitors are configured in hyprland ?
          settings.output_name = "3";
          applications.apps = [
            {
              name = "Shared Desktop";
              prep-cmd = [ doUndoHeadlessDisplay ];
            }
            {
              name = "Exclusive Desktop";
              prep-cmd = [
                doUndoHeadlessDisplay
                {
                  do = "sh -c '${hyprlandDisableOtherMonitorsPreSunshine}'";
                  undo = "sh -c '${hyprlandRestoreDisabledMonitorsPostSunshine}'";
                }
              ];
            }
          ];
        };
      }
      // optionalAttrs hasHomeManager {
        home-manager.sharedModules = [
          {
            wayland.windowManager.hyprland = {
              custom-settings.permission.screenCopy = [ pkgs.sunshine ];
              settings = {
                on = attrsToLuaInlineArgs {
                  "hyprland.start" = ''
                    function()
                      hl.exec_cmd('hyprctl output create headless')
                    end
                  '';
                };
                monitor = [
                  {
                    output = "HEADLESS-1";
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
