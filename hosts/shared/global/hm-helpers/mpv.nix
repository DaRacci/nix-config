{
  anyoneHasPackage,
  ...
}:
{
  pkgs,
  lib,
  ...
}:
{
  programs.firefox.nativeMessagingHosts = lib.mkIf (anyoneHasPackage pkgs.ff2mpv-rust) {
    ff2mpv = true;
  };
}
