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
  github-actions-mcp-server = pkgs.callPackage ./github-actions-mcp-server { };

  # Misc
  orca-slicer-zink = pkgs.callPackage ./orca-slicer-zink { };
  caelestia-shell = pkgs.callPackage ./caelestia/shell.nix { };
  caelestia-cli = pkgs.callPackage ./caelestia/cli.nix { };

  # Helper Stuff
  new-host = pkgs.callPackage ./helpers/new-host.nix { };
  list-ephemeral = pkgs.callPackage ./list-ephemeral { };

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
