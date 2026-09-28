{
  writeShellApplication,
  coreutils,
  fuse3,
  systemd,
  util-linux,
}:
writeShellApplication {
  name = "swfs-mount-hook";
  runtimeInputs = [
    coreutils
    fuse3
    systemd
    util-linux
  ];
  text = builtins.readFile ./swfs-mount-hook.sh;
}
