{
  writeShellApplication,
  yq,
  sops,
  ssh-to-age,
  findutils,
}:
writeShellApplication {
  name = "new-host";
  text = builtins.readFile ./new-host.sh;
  runtimeInputs = [
    yq
    sops
    ssh-to-age
    findutils
  ];
}
