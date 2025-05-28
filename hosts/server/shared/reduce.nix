# Just disable and reduce as much as possible, not sense in keeping stuff around that is not used.
{
  documentation = {
    enable = false;
    man.enable = false;
    nixos.enable = false;
  };
  programs.command-not-found.enable = false;
}
