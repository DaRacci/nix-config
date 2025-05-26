{ pkgs }:
{
  # VR Stuff
  alvr = pkgs.callPackage ./alvr { };

  # Racing Games
  monocoque = pkgs.callPackage ./monocoque { };

  # MCP Servers
  github-actions-mcp-server = pkgs.callPackage ./github-actions-mcp-server { };

  # Misc
  orca-slicer-zink = pkgs.callPackage ./orca-slicer-zink { };

  # Helper Stuff
  new-host = pkgs.callPackage ./helpers/new-host.nix { };
  list-ephemeral = pkgs.callPackage ./list-ephemeral { };
}
