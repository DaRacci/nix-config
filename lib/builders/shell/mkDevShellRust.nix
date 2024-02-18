{ inputs
, system
, name
, pkgsFor

, rustChannel
, crossSystem ? system
, additionalLibraryPath ? (pkgs: [ ])
, ...
}:
let
  pkgs = pkgsFor system;
  inherit (pkgs.lib) optionals;
  inherit (inputs) fenix;

  channel =
    if rustChannel == "nightly"
    then "complete"
    else if rustChannel == "beta"
    then "beta"
    else if rustChannel == "stable"
    then "stable"
    else abort "Unsupported rust channel ${rustChannel}, must be one of nightly, beta, or stable";

  # FIXME :: This is a bit of a hack to get the right target for the right system.
  rust-target =
    if crossSystem == "x86_64-linux"
    then "x86_64-unknown-linux-gnu"
    else if crossSystem == "x86_64-darwin"
    then "x86_64-apple-darwin"
    else if crossSystem == "x86_64-windows"
    then "x86_64-pc-windows-gnu"
    else if crossSystem == "aarch64-linux"
    then "aarch64-unknown-linux-gnu"
    else if crossSystem == "aarch64-darwin"
    then "aarch64-apple-darwin"
    else abort "Unsupported system ${crossSystem}, must be one of x86_64-linux, x86_64-darwin, x86_64-windows, aarch64-linux, or aarch64-darwin";

  rustToolchain = let fenixPkgs = fenix.packages.${system}; in fenixPkgs.combine [
    fenixPkgs.targets."${rust-target}".${channel}.rust-std
    fenixPkgs.${channel}.cargo
    fenixPkgs.${channel}.rustc
    fenixPkgs.${channel}.rust-src
    fenixPkgs.${channel}.rust-analyzer
    fenixPkgs.${channel}.clippy
    fenixPkgs.${channel}.rustfmt
  ];

  crossPackages =
    if system == crossSystem
    then pkgs
    else if crossSystem == "x86_64-linux"
    then pkgs.pkgsCross.gnu64
    else if crossSystem == "x86_64-windows"
    then pkgs.pkgsCross.mingwW64
    else if crossSystem == "aarch64-linux"
    then pkgs.pkgsCross.aarch64-multiplatform
    else pkgs.pkgsCross.${crossSystem};
  inherit (crossPackages) targetPlatform;

  # Define const variables for use in setting up the environment.
  isNative = system == crossSystem;
  useMold = isNative && targetPlatform.isLinux;
  useWine = targetPlatform.isWindows && system == "x86_64-linux";
  TARGET = (builtins.replaceStrings [ "-" ] [ "_" ] (pkgs.lib.toUpper rust-target));
in (import ./mkDevShell.nix { inherit system name pkgsFor; }).overrideAttrs(oldAttrs: {
  inherit name;

  # Arguments that can be reused in a flake or something.
  passthru = {
    inherit rustToolchain;
    inherit isNative;
  };

  nativeBuildInputs = with pkgs; [
    # Possible Dependencies
    pkg-config # Common dependency for many crates

    # Cli Tools
    act # For Github Action testing
    hyperfine # For benchmarking
    cocogitto # For conventional commits
    cargo-nextest # Better cargo test output

    # Rust Components
    rustToolchain

    cargo-udeps
    cargo-audit
    cargo-expand
    cargo-nextest
    cargo-expand
    cargo-cranky
    cargo-edit
  ];
  # ++ optionals (useWine) ([ (pkgs.wine.override { wineBuild = "wine64"; }) ]);
  depsBuildBuild = [ ]
    ++ optionals (!isNative) (with pkgs; [ qemu ])
    ++ optionals (targetPlatform.isWindows) (with crossPackages; [ stdenv.cc windows.mingw_w64_pthreads windows.pthreads ]);

  buildInputs = with crossPackages; [ openssl ]
    ++ optionals (useMold) (with pkgs; [ clang mold ]);

  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [
    openssl
  ] ++ (additionalLibraryPath pkgs));

  # Fixes the CC crate in build scripts.
  "CC_${rust-target}" =
    if useMold
    then "${crossPackages.clang}/bin/${crossPackages.clang.targetPrefix}clang"
    else let inherit (crossPackages.stdenv) cc; in "${cc}/bin/${cc.targetPrefix}cc";

  "CARGO_BUILD_TARGET" = rust-target;

  "CARGO_TARGET_${TARGET}_LINKER" =
    if useMold
    then "${crossPackages.clang}/bin/${crossPackages.clang.targetPrefix}clang"
    else let inherit (crossPackages.stdenv) cc; in "${cc}/bin/${cc.targetPrefix}cc";

  "CARGO_TARGET_${TARGET}_RUSTFLAGS" =
    if useMold then "-C link-arg=-fuse-ld=${crossPackages.mold}/bin/mold"
    else null;

  "CARGO_TARGET_${TARGET}_RUNNER" =
    if isNative
    then null
    else if useWine
    then
      pkgs.writeScript "wine-wrapper" ''
        #!${pkgs.bash}/bin/bash
        export WINEPREFIX="$(mktemp -d)"
        exec ${(pkgs.wine.override { wineBuild = "wine64"; })}/bin/wine64 $@
      ''
    else "${pkgs.qemu}/bin/qemu-${targetPlatform.qemuArch}";
})
