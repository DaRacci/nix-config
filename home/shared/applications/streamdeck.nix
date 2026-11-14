{ pkgs, ... }:
{
  home.packages = [ pkgs.streamcontroller ];

  user.files.persistence.directories = [ ".var/app/com.core447.StreamController" ];
}
