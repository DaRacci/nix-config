{
  writeShellApplication,
  jq,
  yq,
  sops,
  ssh-to-age,
  findutils,
}:
writeShellApplication {
  name = "new-host";
  text = builtins.readFile ./new-host.sh;
  runtimeInputs = [
    jq
    yq
    sops
    ssh-to-age
    findutils
  ];
}
