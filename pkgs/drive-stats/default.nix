{
  writeShellApplication,
  gawk,
  smartmontools,
  toybox,
  util-linux,
  zfs,
}:
writeShellApplication {
  name = "drive-stats";
  text = builtins.readFile ./drive-stats.sh;
  runtimeInputs = [
    gawk
    smartmontools
    toybox
    util-linux
    zfs
  ];
}
