{ inputs, pkgs, ... }:
{
  imports = [
    inputs.nixos-generators.nixosModules.all-formats
  ];

  formatConfigs.proxmox-lxc = _: {
    # If this is a Proxmox LXC and this is its first boot after install
    # We need to get a SSH private key for the host, the pub keys are always present
    # But to prevent packaging the private key in the image, we need to query the key from the user interactively
    #
    # This provides basic validation for the key but does not guarantee the key matches the pub key
    #
    # We store this key in the /persist directory which is queried by sops
    # Sops will the populate the key in the /etc/ssh directory
    system.activationScripts.query-ssh-private-key = {
      deps = with pkgs; [
        busybox
        openssh
      ];
      text =
        let
          persistDirectory = "/persist/etc/ssh/";
        in
        ''
          mkdir -p "${persistDirectory}"
          KEY_FILE="${persistDirectory}/ssh_host_ed25519_key"
          if [ ! -f "$KEY_FILE" ]; then
            # Takes some time for the container to be ready to print the message
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
              KEY=$(echo "$INPUT" | sed -n '/^-----BEGIN OPENSSH PRIVATE KEY-----$/,/^-----END OPENSSH PRIVATE KEY -----$/p')

              if [ -z "$KEY" ]; then
                clear
                echo "Invalid key provided, failed to extract key"
                continue
              fi

              echo "Key provided might be valid"
              echo "Storing the key in $KEY_FILE"
              echo "$KEY" > "$KEY_FILE"
              chmod 600 "$KEY_FILE"

              # Validate the key with ssh-keygen
              ssh-keygen -y -f "$KEY_FILE" > /dev/null
              if [ $? -ne 0 ]; then
                rm "$KEY_FILE"
                clear
                echo "Key provided is invalid, failed to validate the key with ssh-keygen"
                echo "Please provide a valid key"
                continue
              fi

              echo "Key provided is valid"
              break
            done
          fi
        '';
    };
  };
}
