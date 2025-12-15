{ inputs, ... }:
{
  imports = [ inputs.treefmt.flakeModule ];

  perSystem = _: {
    treefmt = {
      projectRootFile = ".git/config";

      programs = {
        actionlint.enable = true;
        deadnix.enable = true;
        nixfmt.enable = true;
        shellcheck.enable = true;
        statix.enable = true;
        mdformat.enable = true;
        mdsh.enable = true;
        keep-sorted.enable = true;
        biome = {
          enable = true;
          settings.formatter = {
            indentStyle = "space";
            indentWidth = 2;
            lineWidth = 80;
          };
          includes = [
            "*.css"
            "*.js"
            "*.json"
          ];
        };
      };

      settings = {
        formatter.shellcheck.excludes = [ ".envrc" ];
        global.excludes = [
          "**/secrets.yaml"
          "**/ssh_host_ed25519_key.pub"
          "hosts/server/nixcloud/provisioning.json"
          "hosts/server/nixio/reddis-mapping.json"
          "hosts/server/nixio/tunnel/credentials.json"
        ];
      };
    };
  };
}
