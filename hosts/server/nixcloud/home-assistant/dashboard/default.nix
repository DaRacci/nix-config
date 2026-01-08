{ lib, ... }:
{
  services.home-assistant.lovelaceConfig = {
    kiosk_mode = import ./kiosk-mode.nix { inherit lib; };
    decluttering_templates = import ./components/decluttering.nix { inherit lib; };
    button_card_templates = import ./components/button-cards { inherit lib; };
    views = [
      (import ./views/home.nix { inherit lib; })
      (import ./views/music.nix { inherit lib; })
      (import ./views/security.nix { inherit lib; })
      (import ./views/server.nix { inherit lib; })
      (import ./views/energy.nix { inherit lib; })
    ];
  };
}
