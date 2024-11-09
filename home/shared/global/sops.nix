{ flake, config, pkgs, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (config.home) username;

  sopsFile = "${flake}/home/${username}/secrets.yaml";
  hasSopsFile = builtins.pathExists sopsFile;

  pubKeyFile = "${flake}/home/${username}/id_ed25519.pub";
  hasPubKeyFile = builtins.pathExists pubKeyFile;

  ssh-to-age-script = let dir = "${config.xdg.configHome}/sops/age"; in pkgs.writeShellApplication {
    name = "ssh-to-age";
    runtimeInputs = [ pkgs.ssh-to-age ];
    text = ''
      if [ ! -d "${dir}" ]; then
          mkdir -p "${dir}";
      fi

      # If the file exists, remove it.
      if [ -f "${dir}/keys.txt" ]; then
        rm "${dir}/keys.txt";
      fi

      # Create an array of possible SSH key paths, and deduplicate based on the content.
      sshKeyPaths=(
        ${lib.trivial.pipe ([
          "${config.user.persistence.root}/.ssh/id_ed25519"
        ] ++ (lib.optionals hasSopsFile [ config.sops.secrets.SSH_PRIVATE_KEY.path ])) [
          (map (path: "\"${path}\""))
          (builtins.concatStringsSep "\n")
        ]}
      )
      mapfile -t sshKeyPaths < <(printf "%s\n" "''${sshKeyPaths[@]}" | sort -u)

      # Convert the SSH keys to age keys, then append them to the age key file with newlines as separators.
      for sshKeyPath in "''${sshKeyPaths[@]}"; do
        if [ -f "''${sshKeyPath}" ]; then
          ssh-to-age --private-key -i "''${sshKeyPath}" >> "${dir}/keys.txt";
        fi
      done
    '';
  };
in
{
  sops = mkIf hasSopsFile {
    defaultSopsFile = "${flake}/home/${username}/secrets.yaml";
    age.sshKeyPaths = [
      config.sops.secrets.SSH_PRIVATE_KEY.path
      "${config.user.persistence.root}/.ssh/id_ed25519"
    ];

    secrets = {
      SSH_PRIVATE_KEY = {
        path = "${config.home.homeDirectory}/.ssh/id_ed25519";
      };
    };
  };

  home.file = mkIf hasPubKeyFile {
    ".ssh/id_ed25519.pub".source = "${flake}/home/${username}/id_ed25519.pub";
  };

  systemd.user.services.ssh-to-age = {
    Unit = {
      Description = "Convert SSH keys to age keys";
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe ssh-to-age-script}";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
