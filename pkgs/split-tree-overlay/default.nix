{
  lib,
  rustPlatform,
  pkg-config,
  wayland,
}:
let
  cargoToml = lib.importTOML ./Cargo.toml;
in
rustPlatform.buildRustPackage {
  pname = cargoToml.package.name;
  version = cargoToml.package.version;

  src = ./.;

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ wayland ];

  meta = {
    description = "Drag-and-drop preview overlay for the hyprland split-tree Lua layout";
    license = lib.licenses.mit;
    mainProgram = cargoToml.package.name;
    platforms = lib.platforms.linux;
  };
}
