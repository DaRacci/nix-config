{
  lib,
  python3,
  writeShellApplication,
}:
let
  wyoming = python3.pkgs.wyoming;
  py = python3.withPackages (_: [ wyoming ]);
in
writeShellApplication {
  name = "wyoming-transcribe";
  runtimeInputs = [ py ];
  text = ''
    exec ${py}/bin/python3 ${./transcribe.py} "$@"
  '';
  meta = {
    description = "Wyoming protocol client that sends WAV audio to a faster-whisper server and writes transcript .txt";
    homepage = "https://github.com/NousResearch/hermes-agent";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ racci ];
    platforms = lib.platforms.linux;
  };
}
