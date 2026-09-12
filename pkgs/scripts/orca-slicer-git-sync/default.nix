{
  writeShellApplication,
  busybox,
  git,
  inotify-tools,
}:
writeShellApplication {
  name = "orca-slicer-git-sync";
  runtimeInputs = [
    git
    inotify-tools
    busybox
  ];
  text = builtins.readFile ./orca-slicer-git-sync.sh;
}
