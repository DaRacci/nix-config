{ self, ... }:
{
  imports = [ "${self}/home/shared/features/cli" ];

  user.persistence.enable = false;

  # Minimising unnecessary packages
  manual.manpages.enable = false;
  programs.man.enable = false;
  fonts.fontconfig.enable = false;
  stylix.enable = false;

  programs.helix = {
    enable = true;
    defaultEditor = true;
  };
}
