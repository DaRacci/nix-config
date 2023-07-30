{ localSystem
, pkgs
, flake-utils
, fenix
, crane
}:

let
  mainPkg = pkgs.callPackage ./default.nix { inherit localSystem flake-utils fenix crane; };
  fenixPkgs = fenix.packages.${localSystem};
in
mainPkg.overrideAttrs (oa: {
  nativeBuildInputs = [
    (fenixPkgs.complete.withComponents [
      "rust-analyzer"
      "clippy-preview"
      "rustfmt-preview"
    ])
  ] ++ (oa.nativeBuildInputs or [ ]);
})
