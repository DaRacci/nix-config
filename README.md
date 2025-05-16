# Nix Config

This is my interpretation of the perfect nix flake, this powers my desktops, vms, containers, and all aspects of my computers.

## Features

- Automated Persistence through TempFS, or snapshotting with BTRFS, with persistable components using [Impermanence]
- Secret management in [NixOS] ([sops-nix]) and [home-manager] ([sops-nix] with [sops])
- Automated Flake dependency updates through Github Actions using [Update-flake-lock]

## Supported Configurations

- [NixOS]-managed
  - Desktops
    - [nixe] (Personal Desktop)
    - [winix] (WSL 2 instance on Windows for Work)
  - Servers
    - [nixai] (Locally hosted AI)
    - [nixcloud] (Replacing usage of external cloud services)
    - [nixdev] (Development)
    - [nixio] (Interface between the web & internal services)
    - [nixmon] (Monitoring)
    - [nixserv] (Nix Cache & Build System)

## Repository Structure

```
.
├─ home          # Root for all user homes
├─── shared      #
├─ hosts         # Root for all hosts
├─── shared      # Auto-Imported modules for all hosts
├─── desktop     # Desktop NixOS systems
├───── shared    # Auto-Imported modules for desktops
├─── laptop      # Laptop NixOS Systems
├───── shared    # Auto-Imported modules for laptops
├─── server      # Server NixOS Systems
├───── shared    # Auto-Imported modules for servers
├─ lib           # Extension to the nixpkgs lib
├─ modules       # Custom NixOS and home-manager modules
├─ overlays      # NixPkgs overlays
└─ pkgs          # Custom Packages
```

## Things on the TODO

> These probably won't happen honestly

- Cosmic Desktop once stabalised

[home-manager]: https://github.com/nix-community/home-manager
[impermanence]: https://github.com/nix-community/impermanence
[nixai]: ./hosts/server/nixai/
[nixcloud]: ./hosts/server/nixcloud/
[nixdev]: ./hosts/server/nixdev/
[nixe]: ./hosts/desktop/nixe/
[nixio]: ./hosts/server/nixio/
[nixmon]: ./hosts/server/nixmon/
[nixos]: https://nixos.org/
[nixserv]: ./hosts/server/nixserv/
[sops]: https://github.com/mozilla/sops
[sops-nix]: https://github.com/Mic92/sops-nix
[update-flake-lock]: https://github.com/DeterminateSystems/update-flake-lock
[winix]: ./hosts/desktop/winix/
