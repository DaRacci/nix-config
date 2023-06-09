{
  description = "The nix-config of an Idiot";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-23.05"; };
    nixpkgs-unstable = { url = "github:nixos/nixpkgs/nixos-unstable"; };

    home-manager = { url = "github:nix-community/home-manager/release-23.05"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixos-hardware = { url = "github:nixos/nixos-hardware"; };

    # TODO!!
    # sops-nix = { url = "github:Mic92/sops-nix"; };
    nix-colours = { url = "github:misterio77/nix-colors"; };
    impermanence = { url = "github:nix-community/impermanence"; };
    nur.url = github:nix-community/NUR;
    # inputs.xremap-flake.url = "github:xremap/nix-flake";
    rust-overlay.url = "github:oxalica/rust-overlay";
    xremap-flake.url = "github:xremap/nix-flake";
    arion.url = "github:hercules-ci/arion";
    nix-doom-emacs.url = "github:nix-community/nix-doom-emacs";
    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = { self, nixpkgs, home-manager, nur, ... }@inputs:
    let
      inherit (self) outputs;
      forEachSystem = nixpkgs.lib.genAttrs [ "aarch64-linux" "x86_64-linux" ];
      forEachPkgs = fn: forEachSystem (system: fn nixpkgs.legacyPackages.${system});

      mkNixos = base-modules: nixpkgs.lib.nixosSystem {
        modules = base-modules ++ [ nur.nixosModules.nur ];
        specialArgs = { inherit inputs outputs; };
      };
      mkHome = modules: home-manager.lib.homeManagerConfiguration {
        inherit modules nixpkgs;
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # TODO : Dont hardcode arch
        # imports = [ nur.HmModules.nur ];
        extraSpecialArgs = { inherit inputs outputs; };
      };
    in rec {
      # Custom packages; Acessible through 'nix build', 'nix shell', etc
      packages = forEachPkgs (pkgs: (import ./pkgs { inherit pkgs; }) // { });

      # Devshell for bootstrapping; Acessible through 'nix develop' or 'nix-shell' (legacy)
      devShells = forEachPkgs (pkgs: (import ./shell.nix { inherit pkgs; }));

      formatter = forEachPkgs (pkgs: pkgs.nixpkgs-fmt); #?? TF is this?

      # Your custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs outputs; };
      # Reusable nixos modules you might want to export; These are usually stuff you would upstream into nixpkgs
      nixosModules = import ./modules/nixos;

      homeManagerModules = import ./modules/home-manager;
      # homeManagerModules = (import ./modules/home-manager) ++ [
      #   nur.hmModules.nur
      # ];

      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild --flake .#your-hostname'
      nixosConfigurations = {
        # Desktops
        # haha get it, nixos + nice = nixe, haha haha am i right. 
        nixe = mkNixos [ ./hosts/nixe ];
      };

      # Standalone home-manager configuration entrypoint
      # Available through 'home-manager --flake .#your-username@your-hostname'
      homeConfigurations = {
        "racci@nixe" = mkHome [ ./home/racci/nixe.nix ];
      };
    };
}
