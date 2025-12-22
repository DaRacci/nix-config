{
  inputs,
  pkgs,
  ...
}:
{
  # VR Stuff
  alvr-bin = pkgs.callPackage ./alvr-bin { };

  # Racing Games
  monocoque = pkgs.callPackage ./monocoque { };

  # MCP Servers
  mcp-sequential-thinking = pkgs.python3Packages.callPackage ./mcp-sequential-thinking { };
  proton-mcp = pkgs.python3Packages.callPackage ./proton-mcp { };
  mcp-server-amazon = pkgs.callPackage ./mcp-server-amazon { };

  # Misc
  orca-slicer-zink = pkgs.callPackage ./orca-slicer-zink { };
  huntress = pkgs.callPackage ./huntress { };
  drive-stats = pkgs.callPackage ./drive-stats { };
  lidarr-plugins = pkgs.callPackage ./lidarr-plugins { };

  # Home Assistant Python Packages
  terminal-manager = pkgs.python3Packages.callPackage ./python/terminal-manager.nix { };
  ssh-terminal-manager = pkgs.python3Packages.callPackage ./python/ssh-terminal-manager.nix { };
  pyuptimekuma = pkgs.python3Packages.callPackage ./python/pyuptimekuma.nix { };
  pyarlo = pkgs.python3Packages.callPackage ./python/pyarlo.nix { };

  # Helper Stuff
  new-host = pkgs.callPackage ./helpers/new-host.nix { };
  list-ephemeral = pkgs.callPackage ./list-ephemeral { };

  # NixIO Guardian
  inherit (pkgs.callPackage ./io-guardian { }) io-guardian-server io-guardian-client;

  # Wine Apps
  take-control-viewer = pkgs.callPackage ./take-control-viewer {
    inherit (inputs.erosanix.lib.x86_64-linux) mkWindowsAppNoCC;
  };

  lix-woodpecker = pkgs.callPackage ./lix-woodpecker {
    inherit inputs;
  };
}
