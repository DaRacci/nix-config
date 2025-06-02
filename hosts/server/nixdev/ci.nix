{
  config,
  pkgs,
  ...
}:
{
  sops.secrets = {
    GITHUB_TOKEN = { };
  };

  services.github-runners = builtins.getAttr (builtins.genList (i: "nixos-runner-${i}") 10) (_: {
    runner = {
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
    };
  });
}
