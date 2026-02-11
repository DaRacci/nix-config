{
  lib,
  docs,
  caddy,
  writeShellApplication,

  open-webpage ? true,
  xdg-utils,
}:
writeShellApplication {
  name = "serve-docs";
  runtimeInputs = [ caddy ] ++ (lib.optional open-webpage xdg-utils);
  text = ''
    caddy file-server --listen :8080 --root ${docs} &
    ${lib.optionalString open-webpage "xdg-open http://localhost:8080"}
    wait
  '';
}
