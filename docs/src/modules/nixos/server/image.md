# Image

The `image.nix` module provides image and VM-related configuration for server hosts.

## SSH Private Key Activation Script

On first boot of a freshly installed host, the SSH private key must be provisioned.
The public key is baked into the image at `/etc/ssh/ssh_host_ed25519_key.pub`, but the private key is deliberately not packaged.
Instead, the activation script prompts the operator interactively to input the private key,
validates it with, and stores it to a persistent location where [sops-nix](https://github.com/Mic92/sops-nix) picks it up.

The script is enabled unconditionally on all server hosts as a no-op unless both of the following hold:

- `/dev/console` is available for I/O (it is under `build-vm -nographic`, where QEMU wires it to the host terminal)
- A persistent SSH key does not already exist.

### Validation

The pasted key is checked in two stages:

1. The key is parsed and validated as a valid Ed25519 private key.
1. The derived public key must match the baked-in public key the image was built with.

On failure the key file is removed and the prompt repeats.

## VM Variant Overrides

All servers import the proxmox-lxc module which inherently breaks `nixos-rebuild build-vm`
because the Proxmox LXC image variant sets `boot.isContainer = true` and therefore disables the initrd.
We override this behavior for `build-vm` so that a runnable QEMU VM can be built from such hosts with the following options:

- `boot.isContainer = false`: restores the initrd and normal VM boot.
- `boot.loader.initScript.enable = false`: avoids a unique-option conflict on `system.build.installBootLoader` between the grub and init-script loaders.
- `virtualisation.qemu.consoles = [ "tty0" "ttyS0,115200n8" ]`: routes boot logs and `/dev/console` to the serial port so they are visible with `-nographic` (the last `console=` becomes `/dev/console`).
- `systemd.services."serial-getty@ttyS0".enable = true`: enables root autologin on the serial console so the VM is usable with `-nographic`.

### Building and running a VM

```bash
nixos-rebuild build-vm --flake .#<hostname>
./result/bin/run-<hostname>-vm -nographic
```

### Building a Proxmox LXC image

```bash
nixos-rebuild build-image --image-variant proxmox-lxc --flake .#<hostname>
```
