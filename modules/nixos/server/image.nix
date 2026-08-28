{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe';

  persistDirectory = "/persist/etc/ssh/";
  sedPath = getExe' pkgs.busybox "sed";
  clearPath = getExe' pkgs.busybox "clear";
  sshKeygenPath = getExe' pkgs.openssh "ssh-keygen";

  queryScript = pkgs.writeShellScript "query-ssh-private-key" ''
    KEY_FILE="${persistDirectory}/ssh_host_ed25519_key"

    if [ -f "$KEY_FILE" ]; then
      exit 0
    fi

    mkdir -p "${persistDirectory}"

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
      KEY=$(echo "$INPUT" | ${sedPath} -n '/^-----BEGIN OPENSSH PRIVATE KEY-----$/,/^-----END OPENSSH PRIVATE KEY-----$/p')

      if [ -z "$KEY" ]; then
        ${clearPath}
        echo "No key provided"
        continue
      fi

      echo "Key provided might be valid"
      echo "Storing the key in $KEY_FILE"
      echo "$KEY" > "$KEY_FILE"
      chmod 600 "$KEY_FILE"

      if ! ${sshKeygenPath} -y -f "$KEY_FILE" >/dev/null 2>&1; then
        ${clearPath}
        rm "$KEY_FILE"
        echo "Key provided is invalid, failed to validate the key with ssh-keygen"
        continue
      fi

      PUB_KEY=$(echo "$KEY" | ${sshKeygenPath} -y -f /dev/stdin 2> /dev/null)
      EXPECTED_PUB_KEY=$(cat /etc/ssh/ssh_host_ed25519_key.pub)
      if [ "$PUB_KEY" != "$EXPECTED_PUB_KEY" ]; then
        ${clearPath}
        rm "$KEY_FILE"
        echo "Key provided does not match the public key"
        echo "Expected: $EXPECTED_PUB_KEY"
        echo "Got: $PUB_KEY"
        echo "Please provide the correct private key"
        continue
      fi

      echo "Key provided is valid"
      break
    done
  '';
in
{
  config = {
    virtualisation.vmVariant = {
      boot.isContainer = lib.mkForce false;
      boot.loader.initScript.enable = lib.mkForce false;
      systemd.services."serial-getty@ttyS0".enable = lib.mkForce true;
    };

    programs.bash.loginShellInit = ''
      if [ "$(id -u)" = "0" ] && [ ! -f "${persistDirectory}/ssh_host_ed25519_key" ]; then
        echo "SSH host private key not found at ${persistDirectory}/ssh_host_ed25519_key"
        ${queryScript}
      fi
    '';
  };
}
