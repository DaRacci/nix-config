{
  writeShellApplication,
  fd,
  lib,
}:
writeShellApplication {
  name = "list-ephemeral";
  runtimeInputs = [ fd ];

  text = builtins.readFile ./list-ephemeral.sh;

  meta = {
    description = "List ephemeral paths that will be lost when restarting the system";
    longDescription = ''
      This script lists all the ephemeral paths that will be lost when restarting the system.
      There are some builtin paths that are ignored and will not be displayed such as known caches,
      and files we know about but want to keep as ephemeral.

      Any arguments provided will be passed directly to fd.
    '';
    maintainer = [ lib.maintainers.Racci ];
    license = lib.licenses.gpl3;
    platforms = lib.platforms.linux;
  };
}
