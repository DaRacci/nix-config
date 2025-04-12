{ inputs, ... }:
{
  imports = [ inputs.lan-mouse.homeManagerModules.default ];

  programs.lan-mouse = {
    enable = true;
    systemd = true;
    settings = {
      release_bind = [ ];
      port = 4242;
    };
  };

  user.persistence.directories = [ ".config/lan-mouse" ];
}
