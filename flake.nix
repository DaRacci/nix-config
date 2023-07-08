{
  description = "The nix-config of an Idiot";

  inputs = {
    # Packages
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-23.05"; };
    nixpkgs-unstable = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    nur = { url = "github:nix-community/NUR"; };

    # Base Modules
    home-manager = { url = "github:nix-community/home-manager/release-23.05"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixos-hardware = { url = "github:nixos/nixos-hardware"; };
    sops-nix = { url = "github:Mic92/sops-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    impermanence = { url = "github:nix-community/impermanence"; };
    nix-colours = { url = "github:misterio77/nix-colors"; };

    # Containers & Stuff
    arion = { url = "github:hercules-ci/arion"; };

    # Optional Modules
    hyprland = { url = "github:hyprwm/Hyprland"; };
    nix-doom-emacs = { url = "github:nix-community/nix-doom-emacs"; };
    # inputs.xremap-flake.url = "github:xremap/nix-flake";
    # rust-overlay.url = "github:oxalica/rust-overlay";
    # xremap-flake.url = "github:xremap/nix-flake";
  };

  outputs = { self, nixpkgs, nur, home-manager, impermanence, sops-nix, nix-colours, ... }@inputs:
    let
      inherit (self) outputs;
      inherit (self) system;
      forEachSystem = nixpkgs.lib.genAttrs [ "aarch64-linux" "x86_64-linux" ];
      forEachPkgs = fn: forEachSystem (system: fn nixpkgs.legacyPackages.${system});

      # Modules which are inherited by all system configurations
      systemModules = [
        # (builtins.toString ./hosts/common/global)
        nur.nixosModules.nur
        home-manager.nixosModules.home-manager
        impermanence.nixosModules.impermanence
      ];

      # Modules which are inherited by all home-manager configurations
      homeModules = [
        # (builtins.toString ./home/common/global)
        nur.hmModules.nur
        sops-nix.homeManagerModule
        impermanence.nixosModules.home-manager.impermanence
        nix-colours.homeManagerModules.default
      ];

      mkNixos = unique-modules: nixpkgs.lib.nixosSystem {
        modules = systemModules ++ unique-modules;
        specialArgs = { inherit inputs outputs; };
      };

      mkHome = unique-modules: home-manager.lib.homeManagerConfiguration {
        inherit nixpkgs;
        pkgs = nixpkgs.legacyPackages."${system}";
        modules = homeModules ++ unique-modules;
        extraSpecialArgs = { inherit inputs outputs; };
      };
    in
    {
      # Custom packages; Acessible through 'nix build', 'nix shell', etc
      packages = forEachPkgs (pkgs: (import ./pkgs { inherit pkgs; }) // { });

      # Devshell for bootstrapping; Acessible through 'nix develop' or 'nix-shell' (legacy)
      devShells = forEachPkgs (pkgs: (import ./shell.nix { inherit pkgs; }));

      formatter = forEachPkgs (pkgs: pkgs.nixpkgs-fmt); #?? TF is this?

      # Your custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs outputs; };

      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;

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
