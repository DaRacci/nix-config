{ pkgs, ... }:
{
  home.packages = [ pkgs.streamcontroller ];

  user.persistence.directories = [ ".var/app/com.core447.StreamController" ];
}
