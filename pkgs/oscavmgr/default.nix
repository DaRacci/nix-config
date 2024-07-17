{ writeShellApplication
, callPackage
, libz
, openssl
, lib
}:
let
  OSCAvMgr = callPackage ./oscavmgr.nix { };
  VrcAdvert = callPackage ./VrcAdvert.nix { };
in
writeShellApplication {
  name = "oscavmgr";

  runtimeInputs = [ libz openssl ];

  text = /*bash*/ ''
    trap 'jobs -p | xargs kill' EXIT

    ${VrcAdvert}/bin/VrcAdvert 9402 9002 &
    ${OSCAvMgr}/bin/oscavmgr
  '';

  meta = {
    description = "";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    maintainers = [ "DaRacci" ];
  };
}
