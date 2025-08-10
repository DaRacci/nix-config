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
  mcp-sequential-thinking = pkgs.python3Packages.callPackage ./mcp-sequential-thinking { };

  # Misc
  orca-slicer-zink = pkgs.callPackage ./orca-slicer-zink { };

  # Home Assistant Python Packages
  terminal-manager = pkgs.python3Packages.callPackage ./python/terminal-manager.nix { };
  ssh-terminal-manager = pkgs.python3Packages.callPackage ./python/ssh-terminal-manager.nix { };
  pyuptimekuma = pkgs.python3Packages.callPackage ./python/pyuptimekuma.nix { };

  # Helper Stuff
  new-host = pkgs.callPackage ./helpers/new-host.nix { };
  list-ephemeral = pkgs.callPackage ./list-ephemeral { };

  # Wine Apps
  take-control-viewer = pkgs.callPackage ./take-control-viewer {
    inherit (inputs.erosanix.lib.${pkgs.system}) mkWindowsAppNoCC;
  };
}
