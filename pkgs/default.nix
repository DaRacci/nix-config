{
  inputs,
  pkgs,
}:
{
  # VR Stuff
  alvr = pkgs.callPackage ./alvr { };

  # Racing Games
  monocoque = pkgs.callPackage ./monocoque { };

  # MCP Servers
  mcpo = pkgs.python3Packages.callPackage inputs.mcpo { };
  github-actions-mcp-server = pkgs.callPackage ./github-actions-mcp-server { };
  mcp-sequential-thinking = pkgs.python3Packages.callPackage ./mcp-sequential-thinking { };

  # Misc
  orca-slicer-zink = pkgs.callPackage ./orca-slicer-zink { };
  caelestia-shell = pkgs.callPackage ./caelestia/shell.nix { };
  caelestia-cli = pkgs.callPackage ./caelestia/cli.nix { };

  # Home Assistant Python Packages
  terminal-manager = pkgs.python3Packages.callPackage ./python/terminal-manager.nix { };
  ssh-terminal-manager = pkgs.python3Packages.callPackage ./python/ssh-terminal-manager.nix { };
  pyuptimekuma = pkgs.python3Packages.callPackage ./python/pyuptimekuma.nix { };

  # Helper Stuff
  new-host = pkgs.callPackage ./helpers/new-host.nix { };
  list-ephemeral = pkgs.callPackage ./list-ephemeral { };

  # Wine Apps
  take-control-viewer = pkgs.callPackage ./take-control-viewer {
    inherit (inputs.erosanix.lib.x86_64-linux) mkWindowsAppNoCC;
  };
  # PR Packages
  protonup-rs = (pkgs.callPackage "${inputs.protonup-rs}" { }).overrideAttrs (oldAttrs: {
    cargoHash = "sha256-02uOVJtU52EWQn+Z2rHCum9+jodByYTDcLyMkgfpjwc=";
    cargoDeps = oldAttrs.cargoDeps.overrideAttrs (oldAttrs: {
      vendorStaging = oldAttrs.vendorStaging.overrideAttrs (_old: {
        outputHash = "sha256-02uOVJtU52EWQn+Z2rHCum9+jodByYTDcLyMkgfpjwc=";
      });
    });
  });
}
