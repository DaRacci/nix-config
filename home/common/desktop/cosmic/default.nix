{ inputs, pkgs, ... }:
let
  inherit (inputs)
    cosmic-applets cosmic-applibrary cosmic-bg cosmic-comp cosmic-launcher
    cosmic-notifications cosmic-panel cosmic-settings cosmic-settings-daemon;

  mkPatched = name:
    let
      patched = pkgs.applyPatches {
        name = "${name}";
        src = builtins.fetchTarball "https://github.com/pop-os/${name}/archive/master.tar.gz";
        patches = [ ../../../pkgs/cosmic/${name}.patch ];
      };
    in
    (import inputs.flake-compat {
      src = patched;
    }).defaultNix;

  # cosmic-osd = mkPatched;
  # cosmic-session = mkPatched;
  # cosmic-workspaces = mkPatched;
  # xdg-desktop-portal-cosmic = mkPatched;
in
{
  imports = [ ../wayland ];

  home.packages = builtins.map
    (flake: flake.outputs.packages.${builtins.currentSystem}.default) [
    cosmic-applets
    cosmic-applibrary
    cosmic-bg
    cosmic-comp
    cosmic-launcher
    cosmic-notifications
    (mkPatched "cosmic-osd")
    cosmic-panel
    (mkPatched "cosmic-session")
    cosmic-settings
    cosmic-settings-daemon
    (mkPatched "cosmic-workspaces-epoch")
    (mkPatched "xdg-desktop-portal-cosmic")
  ];
}
