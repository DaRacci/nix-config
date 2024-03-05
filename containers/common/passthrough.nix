{ config, ... }:
let
  domain = config.virtualisation.arion.projects.global.settings.services.caddy.service.environment.DOMAIN;
in
{
  service.environment = {
    DOMAIN = domain;
  };
}
