{ flake, ... }:
{
  imports = [ "${flake}/home/shared/features/cli" ];

  user.persistence.enable = false;
  stylix.enable = false;
}
