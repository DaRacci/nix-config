# TODO - Use the programs.appimage option when moving to release 24.05
{ pkgs, lib, ... }:
let
  package = pkgs.appimage-run.override {
    extraPkgs =
      pkgs: with pkgs; [
        libthai
        libxkbcommon
      ];
  };
in
{
  boot.binfmt.registrations.appimage = {
    wrapInterpreterInShell = false;
    interpreter = lib.getExe package;
    recognitionType = "magic";
    offset = 0;
    mask = "\\xff\\xff\\xff\\xff\\x00\\x00\\x00\\x00\\xff\\xff\\xff";
    magicOrExtension = "\\x7fELF....AI\\x02";
  };

  environment.systemPackages = [ package ];
}
