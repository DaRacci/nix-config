{ pkgs
, lib
, localSystem
, crossSystem ? localSystem
, workspace ? null
, flake-utils
, crane
, fenix
}:
let
  # TODO: This is a hack to get the right target for the right system.

  target = let inherit (flake-utils.lib) system; in
    if crossSystem == system.x86_64-linux
    then "x86_64-unknown-linux-gnu"
    else if crossSystem == system.x86_64-darwin
    then "x86_64-apple-darwin"
    else if crossSystem == system.x86_64-windows
    then "x86_64-pc-windows-gnu"
    else if crossSystem == system.aarch64-linux
    then "aarch64-unknown-linux-gnu"
    else if crossSystem == system.aarch64-darwin
    then "aarch64-apple-darwin"
    else abort "Unsupported system";

  toolchain = with fenix.packages.${localSystem}; combine [
    targets.${target}.latest.rust-std
    (complete.withComponents [
      "cargo"
      "rustc"
      "rust-src"
      "clippy-preview"
      "rustfmt-preview"
    ])
  ];

  craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;
  TARGET = (builtins.replaceStrings [ "-" ] [ "_" ] (pkgs.lib.toUpper target));

  crossPackages = let inherit (flake-utils.lib) system; in
    if localSystem == crossSystem
    then pkgs
    else if crossSystem == system.x86_64-linux
    then pkgs.pkgsCross.gnu64
    else if crossSystem == system.x86_64-windows
    then pkgs.pkgsCross.mingwW64
    else if crossSystem == system.aarch64-linux
    then pkgs.pkgsCross.aarch64-multiplatform
    else pkgs.pkgsCross.${crossSystem};

  commonArgs = {
    src = craneLib.cleanCargoSource (craneLib.path ./.);
    cargoLock = craneLib.path ./Cargo.lock;
  };

  cargoCrate =
    let
      inherit (crossPackages) targetPlatform;

      isNative = localSystem == crossSystem;
      useMold = isNative && targetPlatform.isLinux;
      useWine = targetPlatform.isWindows && localSystem == flake-utils.lib.system.x86_64-linux;
    in
    craneLib.buildPackage (commonArgs // {
      cargoExtraArgs = if workspace != null then "--package ${workspace}" else "";

      strictDeps = true;
      doCheck = true;

      passthru = { inherit craneLib commonArgs; };

      depsBuildBuild = [ ]
        ++ lib.optionals (!isNative) (with pkgs; [ qemu ])
        ++ lib.optionals (targetPlatform.isWindows) (with crossPackages; [ stdenv.cc windows.mingw_w64_pthreads windows.pthreads ]);

      buildInputs = with crossPackages; [ openssl ]
        ++ lib.optionals (useMold) (with pkgs; [ clang mold ]);

      nativeBuildInputs = with pkgs; [ pkg-config ]
        ++ lib.optionals (useWine) ([ (pkgs.wine.override { wineBuild = "wine64"; }) ]);

      "CARGO_BUILD_TARGET" = target;

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
    });
in
cargoCrate
