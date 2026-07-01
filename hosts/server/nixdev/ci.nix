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

  server.tests.units.github-runners = {
    testScript = ''
      nixdev.succeed("systemctl show github-runner-nixos-runner-0.service | grep -i loadstate")
    '';
  };
}
