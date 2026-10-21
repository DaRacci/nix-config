{
  writeShellApplication,
  openssh,
  procps,
  socat,
  util-linux,
}:
writeShellApplication {
  name = "ssh-relay";
  runtimeInputs = [
    socat
    procps
    openssh
    util-linux
  ];
  text = builtins.readFile ./ssh-relay.sh;
}
