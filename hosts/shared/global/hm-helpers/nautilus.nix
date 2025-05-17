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
  services.gnome.sushi.enable = anyoneHasPackage pkgs.nautilus;
  environment.pathsToLink = lib.mkIf (anyoneHasPackage pkgs.nautilus) [
    "/share/nautilus-python/extensions"
  ];
}
