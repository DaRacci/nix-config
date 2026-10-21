{
  writeShellApplication,
  ssh-to-age,
  uutils-coreutils-noprefix,
}:
writeShellApplication {
  name = "ssh-to-age-keys";
  runtimeInputs = [
    uutils-coreutils-noprefix
    ssh-to-age
  ];
  text = builtins.readFile ./ssh-to-age-keys.sh;
}
