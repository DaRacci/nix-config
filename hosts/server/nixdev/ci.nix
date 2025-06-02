{
  config,
  pkgs,
  lib,
  ...
}:
{
  sops.secrets = {
    GITHUB_TOKEN = { };
  };

  services.github-runners = lib.genAttrs (builtins.genList (i: "nixos-runner-${toString i}") 10) (_: {
    enable = true;
    replace = true;
    user = null;
    group = null;
    url = "https://github.com/DaRacci/nix-config";
    tokenFile = config.sops.secrets.GITHUB_TOKEN.path;
    extraPackages = with pkgs; [
      git
      jq
      gh
    ];
  });
}
