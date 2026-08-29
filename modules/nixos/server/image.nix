{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe';

  persistDirectory = if config.host.persistence.enable then "/persist/etc/ssh" else "/etc/ssh";
  sedPath = getExe' pkgs.busybox "sed";
  clearPath = getExe' pkgs.busybox "clear";
  testPath = getExe' pkgs.busybox "test";
  catPath = getExe' pkgs.busybox "cat";
  sshKeygenPath = getExe' pkgs.openssh "ssh-keygen";

  consolePath = "/dev/console";
  queryScript = ''
    # The script runs as a systemd service, so stdout/stderr go to the journal.
    # Redirect to /dev/console so the prompt is visible on the serial console.
    exec >${consolePath} 2>&1

    mkdir -p "${persistDirectory}"
    printf "Persist directory: ${persistDirectory}\n"
    echo "Checking for existing SSH private key..."

    # Only prompt if /dev/console is writable and usable for I/O.
    if ! ${testPath} -w ${consolePath} || ! ${testPath} -c ${consolePath}; then
      echo "Skipping SSH private key prompt: ${consolePath} not available" >&2
      exit 0
    fi

    KEY_FILE="${persistDirectory}/ssh_host_ed25519_key"
    if [ ! -f "$KEY_FILE" ]; then
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
        INPUT=$(${catPath} ${consolePath})
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
    fi
  '';
in
{
  config = {
    virtualisation.vmVariant = {
      boot.isContainer = lib.mkForce false;
      boot.loader.initScript.enable = lib.mkForce true;
      boot.loader.grub.enable = false;
      console.enable = lib.mkForce false;
      # Route kernel + /dev/console output to the serial port so boot logs and the activation-script prompt are visible under `-nographic`.
      # The last console= becomes /dev/console, hence ttyS0 last.
      virtualisation.qemu.consoles = [
        "tty0"
        "ttyS0,115200n8"
      ];
      systemd.services."serial-getty@ttyS0".enable = lib.mkVMOverride true;
      systemd.services."getty@tty1".enable = lib.mkVMOverride false;
      systemd.services."autovt@".enable = lib.mkVMOverride false;
    };

    system.activationScripts = {
      setupSecrets.deps = lib.mkAfter [ "ssh-host-key-provision" ];
      ssh-host-key-provision = {
        deps = [
          "specialfs"
          "usrbinenv"
          "binsh"
          "etc"
        ];
        text = queryScript;
      };
    };
  };
}
