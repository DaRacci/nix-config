{
  inputs,
  pkgs,
  lib,
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
  code-review-graph = pkgs.python3Packages.callPackage ./code-review-graph { };

  # Wyoming STT Client for Hermes
  wyoming-transcribe-client = pkgs.callPackage ./wyoming-transcribe-client { };

  # Misc
  orca-slicer-zink = pkgs.callPackage ./orca-slicer-zink { };
  huntress = pkgs.callPackage ./huntress { };
  drive-stats = pkgs.callPackage ./drive-stats { };
  lidarr-plugins = pkgs.callPackage ./lidarr-plugins { };
  hypr-gamemode = pkgs.callPackage ./hypr-gamemode { };
  uvtools = pkgs.callPackage ./uvtools { };

  # Hermes Agent Python Plugins
  mnemosyne-memory = pkgs.python312Packages.callPackage ./python/mnemosyne-memory.nix { };
  mnemosyne-hermes = pkgs.python312Packages.callPackage ./python/mnemosyne-hermes.nix { };
  mnemosyne-memory-all = pkgs.mnemosyne-memory.overridePythonAttrs (old: {
    dependencies = old.passthru.optional-dependencies.all;
  });

  # Home Assistant Python Packages
  terminal-manager = pkgs.python3Packages.callPackage ./python/terminal-manager.nix { };
  ssh-terminal-manager = pkgs.python3Packages.callPackage ./python/ssh-terminal-manager.nix { };
  pyuptimekuma = pkgs.python3Packages.callPackage ./python/pyuptimekuma.nix { };
  pyarlo = pkgs.python3Packages.callPackage ./python/pyarlo.nix { };

  # Scripts n stuff
  new-host = pkgs.callPackage ./helpers/new-host.nix { };
  list-ephemeral = pkgs.callPackage ./list-ephemeral { };
  inherit (pkgs.callPackage ./scripts { inherit lib; }) folder-diff image-compressor;

  # NixIO Guardian
  inherit (pkgs.callPackage ./io-guardian { }) io-guardian-server io-guardian-client;

  # Wine Apps
  take-control-viewer = pkgs.callPackage ./take-control-viewer {
    inherit (inputs.erosanix.lib.x86_64-linux) mkWindowsAppNoCC;
    wine = pkgs.wineWow64Packages.full;
  };

  lix-woodpecker = pkgs.callPackage ./lix-woodpecker {
    inherit inputs;
  };

  jj-desc = pkgs.callPackage ./jj-desc { };
  jj-pre-push = pkgs.python3Packages.callPackage ./jj-pre-push { };
}
