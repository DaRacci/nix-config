{
  config,
  pkgs,
  lib,
  ...
}:
(import ../lib.nix { inherit lib; }).mkPluginModule config {
  name = "hermes-hora";
  extraPluginSrc = pkgs.fetchFromGitHub {
    name = "hermes-hora";
    owner = "meleeislandbot";
    repo = "hermes-hora";
    rev = "v0.1.1";
    hash = "sha256-7x5zfogYe8yDaMQZCqHL2lHyd6Y2xy9rsgF+kSl0t+A=";
  };

  settings = {
    plugins.entries.hermes-hora.timezone = config.time.timeZone;
  };
}
