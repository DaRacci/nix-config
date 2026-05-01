{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    getExe'
    mkIf
    mkMerge
    mkOption
    mkEnableOption
    types
    optional
    literalExpression
    ;
  inherit (types) path;

  cfg = config.core.generators;
in
{
  imports = [
    inputs.nixos-generators.nixosModules.all-formats
  ];

  options.core.generators = {
    enable = mkEnableOption "generators configuration" // {
      default = config.core.enable;
    };

    proxmoxLXC = {
      enable = mkEnableOption "Proxmox LXC generator configuration" // {
        default = cfg.enable && config.host.device.isVirtual;
        defaultText = literalExpression "cfg.enable && config.host.device.isVirtual";
      };

      sedPath = mkOption {
        type = path;
        default = getExe' pkgs.busybox "sed";
        defaultText = literalExpression ''getExe' pkgs.busybox "sed"'';
        description = "Sed package to use for validating the SSH private key provided by the user";
      };

      sshKeygenPath = mkOption {
        type = path;
        default = getExe' pkgs.openssh "ssh-keygen";
        defaultText = literalExpression ''getExe' pkgs.openssh "ssh-keygen"'';
        description = "SSH package to use for validating the SSH private key provided by the user";
      };

      clearPath = mkOption {
        type = path;
        default = getExe' pkgs.busybox "clear";
        defaultText = literalExpression ''getExe' pkgs.busybox "clear"'';
        description = "Clear binary to use for clearing the screen when asking the user for the SSH private key";
      };

    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      assertions = optional cfg.proxmoxLXC.enable {
        assertion = config.environment.etc ? "ssh/ssh_host_ed25519_key.pub";
        message = "The Proxmox LXC generator requires the SSH host public key to be present in the image at /etc/ssh/ssh_host_ed25519_key.pub";
      };

      formatConfigs.proxmox-lxc = mkIf cfg.proxmoxLXC.enable (_: {

        # If this is a Proxmox LXC and this is its first boot after install
        # We need to get a SSH private key for the host, the pub keys are always present
        # But to prevent packaging the private key in the image, we need to query the key from the user interactively
        #
        # This provides basic validation for the key but does not guarantee the key matches the pub key
        #
        # We store this key in the /persist directory which is queried by sops
        # Sops will the populate the key in the /etc/ssh directory
        system.activationScripts.query-ssh-private-key.text =
          let
            persistDirectory = "/persist/etc/ssh/";
          in
          ''
            mkdir -p "${persistDirectory}"
            KEY_FILE="${persistDirectory}/ssh_host_ed25519_key"
            if [ ! -f "$KEY_FILE" ]; then
              if ! test -t 0; then
                echo "Skipping SSH private key prompt: no controlling terminal available" >&2
                exit 0
              fi

              # Takes some time for the container to be ready to print the message.
              # TODO:Is there a better way to do this?
              sleep 2

              while true; do

                echo "Please provide the SSH private key for the host"
                echo "This key will be used to authenticate the host to the container"
                echo "The key should be in the format:"
                echo "-----BEGIN OPENSSH PRIVATE KEY-----"
                echo "..."
                echo "-----END OPENSSH PRIVATE KEY-----"
                echo ""
                echo "To finish providing the key, press Ctrl+D"
                echo "Please paste the key here:"
                INPUT=$(</dev/stdin)
                KEY=$(echo "$INPUT" | ${cfg.proxmoxLXC.sedPath} -n '/^-----BEGIN OPENSSH PRIVATE KEY-----$/,/^-----END OPENSSH PRIVATE KEY-----$/p')

                if [ -z "$KEY" ]; then
                  ${cfg.proxmoxLXC.clearPath}
                  echo "No key provided"
                  continue
                fi

                echo "Key provided might be valid"
                echo "Storing the key in $KEY_FILE"
                echo "$KEY" > "$KEY_FILE"
                chmod 600 "$KEY_FILE"

                echo "Key from file"
                cat "$KEY_FILE"

                ${cfg.proxmoxLXC.sshKeygenPath} -y -f "$KEY_FILE"
                if [ $? -ne 0 ]; then
                  ${cfg.proxmoxLXC.clearPath}
                  rm "$KEY_FILE"
                  echo "Key provided is invalid, failed to validate the key with ssh-keygen"
                  continue
                fi

                PUB_KEY=$(echo "$KEY" | ${cfg.proxmoxLXC.sshKeygenPath} -y -f /dev/stdin 2> /dev/null)
                EXPECTED_PUB_KEY=$(cat /etc/ssh/ssh_host_ed25519_key.pub)
                if [ "$PUB_KEY" != "$EXPECTED_PUB_KEY" ]; then
                  ${cfg.proxmoxLXC.clearPath}
                  echo "Key provided does not match the public key"
                  echo "Expected: $EXPECTED_PUB_KEY"
                  echo "Got: $PUB_KEY"
                  echo "Please provide the correct private key"
                  continue
                fi

                echo "Key provided is valid"
                break
              done
            fi
          '';
      });
    })
  ];
}
