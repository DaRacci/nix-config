{
  description = "Foo Bar Rust Project";

  nixConfig = {
    extra-substituters = [ "https://racci.cachix.org" ];
    extra-trusted-public-keys = [ "racci.cachix.org-1:Kl4opLxvTV9c77DpoKjUOMLDbCv6wy3GVHWxB384gxg=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    crane = { url = "github:ipetkov/crane"; inputs.nixpkgs.follows = "nixpkgs"; };
    fenix = { url = "github:nix-community/fenix"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = { nixpkgs, flake-utils, crane, fenix, ... }:
    let
      # TODO - Darwin support (error: don't yet have a `targetPackages.darwin.LibsystemCross for x86_64-apple-darwin`)
      targets = [ "x86_64-linux" "aarch64-linux" "x86_64-windows" ]; #++ flake-utils.lib.eachDefaultSystem;
      onAll = localSystem: f: (builtins.foldl' (attr: target: attr // (f target)) { } targets);
    in
    flake-utils.lib.eachDefaultSystem (localSystem:
      let
        pkgs = import nixpkgs { system = localSystem; };

        cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
        hasSubCrates = (builtins.length (cargoToml.workspace.members or [ ])) >= 1;

        packages = onAll localSystem
          (crossSystem:
            let
              disambiguate = name: if crossSystem == localSystem then name else "${name}-${crossSystem}";
            in
            (if hasSubCrates then
              let
                members = cargoToml.workspace.default-members or [ ];
                getCargoToml = path: builtins.fromTOML (builtins.readFile (./. + "/${path}" + "/Cargo.toml"));
                memberName = path: let cargo = getCargoToml path; in cargo.package.name;
                getPkg = workspace: pkgs.callPackage ./default.nix { inherit localSystem crossSystem flake-utils crane fenix workspace; };
              in
              if builtins.length members >= 1
              then builtins.listToAttrs (builtins.map (member: { name = disambiguate (memberName member); value = let split = builtins.split "/" member; in getPkg (builtins.elemAt split (builtins.length split - 1)); }) members)
              else builtins.listToAttrs (builtins.map (member: { name = disambiguate (memberName "crates/${member}"); value = getPkg member; }) (builtins.attrNames (builtins.readDir ./crates)))
            else [ ]) // builtins.listToAttrs [{ name = disambiguate "default"; value = pkgs.callPackage ./default.nix { inherit localSystem crossSystem flake-utils crane fenix; }; }]
          );
      in
      {
        packages = packages // {
          all = pkgs.symlinkJoin {
            name = "all";
            paths = builtins.attrValues packages;
          };
        };

        devShell = pkgs.callPackage ./shell.nix { inherit localSystem flake-utils crane fenix; };

        checks = let package = packages.default; inherit (package) craneLib commonArgs; in {
          fmt = craneLib.cargoFmt commonArgs;

          clippy = craneLib.cargoClippy (commonArgs // {
            inherit (package) cargoArtifacts;
            cargoClippyExtraArgs = "--workspace -- --deny warnings";
          });
        };
      });
}
