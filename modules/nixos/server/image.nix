{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe';

  provisioningDirectory = dirOf config.core.openssh.hostPrivateKeyPath;
  clearPath = getExe' pkgs.busybox "clear";
  sttyPath = getExe' pkgs.busybox "stty";
  testPath = getExe' pkgs.busybox "test";
  trPath = getExe' pkgs.busybox "tr";
  sshKeygenPath = getExe' pkgs.openssh "ssh-keygen";

  consolePath = "/dev/console";
  queryScript = ''
    # The script runs as a systemd service, so stdout/stderr go to the journal.
    # Redirect to /dev/console so the prompt is visible on the serial console.
    exec >${consolePath} 2>&1

    mkdir -p "${provisioningDirectory}"
    printf "Provisioning directory: ${provisioningDirectory}\n"
    echo "Checking for existing SSH private key..."

    # Only prompt if /dev/console is writable and usable for I/O.
    if ! ${testPath} -w ${consolePath} || ! ${testPath} -c ${consolePath}; then
      echo "Skipping SSH private key prompt: ${consolePath} not available" >&2
      exit 0
    fi

    KEY_FILE="${config.core.openssh.hostPrivateKeyPath}"
    if [ ! -f "$KEY_FILE" ]; then
      CARRIAGE_RETURN=$(printf '\r')
      TTY_STATE=$(${sttyPath} -F ${consolePath} -g 2>/dev/null || true)
      TTY_RESTORED=0

      restore_console_tty() {
        if [ "$TTY_RESTORED" -eq 1 ]; then
          return 0
        fi

        TTY_RESTORED=1
        exec 3<&- 2>/dev/null || true

        if [ -n "$TTY_STATE" ]; then
          ${sttyPath} -F ${consolePath} "$TTY_STATE" >/dev/null 2>&1 || true
        fi
      }

      trap 'restore_console_tty' EXIT HUP INT TERM

      if ! ${sttyPath} -F ${consolePath} icanon icrnl min 1 time 0 >/dev/null 2>&1; then
        echo "Warning: failed to set tty mode on ${consolePath}, continuing with current settings" >&2
      fi

      if ! exec 3<${consolePath}; then
        echo "Skipping SSH private key prompt: failed to open ${consolePath} for input" >&2
        restore_console_tty
        exit 0
      fi

      read_console_line() {
        CONSOLE_LINE=
        if IFS= read -r CONSOLE_LINE <&3; then
          READ_STATUS=0
        else
          READ_STATUS=$?
        fi

        CONSOLE_LINE=$(printf '%s' "$CONSOLE_LINE" | ${trPath} -d "$CARRIAGE_RETURN")

        if [ "$READ_STATUS" -eq 0 ] || [ -n "$CONSOLE_LINE" ]; then
          return 0
        fi

        return 1
      }

      read_private_key() {
        COLLECTING=0
        KEY=

        while true; do
          if ! read_console_line; then
            ${clearPath}
            if [ "$COLLECTING" -eq 1 ]; then
              echo "Input cancelled, partial key discarded"
              return 2
            fi

            echo "No key provided"
            return 1
          fi

          if [ "$COLLECTING" -eq 0 ]; then
            if [ "$CONSOLE_LINE" = "-----BEGIN OPENSSH PRIVATE KEY-----" ]; then
              COLLECTING=1
              KEY="$CONSOLE_LINE"
            fi

            continue
          fi

          KEY=$(printf '%s\n%s' "$KEY" "$CONSOLE_LINE")
          if [ "$CONSOLE_LINE" = "-----END OPENSSH PRIVATE KEY-----" ]; then
            return 0
          fi
        done
      }

      while true; do
        echo "Please provide the SSH private key for the host"
        echo "This key will be used to authenticate the host to the container"
        echo "The key should be in the format:"
        echo "-----BEGIN OPENSSH PRIVATE KEY-----"
        echo "..."
        echo "-----END OPENSSH PRIVATE KEY-----"
        echo ""
        echo "Paste the key exactly as shown above."
        echo "If the final END line does not submit automatically, press Ctrl+D to finish."
        echo "Press Ctrl+D before the BEGIN line to restart this prompt."
        echo "Press Ctrl+D during entry to discard a partial key and start over."
        echo "Please paste the key here:"

        if ! read_private_key; then
          continue
        fi

        echo "Key provided might be valid"
        echo "Storing the key in $KEY_FILE"
        printf '%s\n' "$KEY" > "$KEY_FILE"
        chmod 600 "$KEY_FILE"

        if ! ${sshKeygenPath} -y -f "$KEY_FILE" >/dev/null 2>&1; then
          ${clearPath}
          rm "$KEY_FILE"
          echo "Key provided is invalid, failed to validate the key with ssh-keygen"
          continue
        fi

        PUB_KEY=$(${sshKeygenPath} -y -f "$KEY_FILE" 2> /dev/null)
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
