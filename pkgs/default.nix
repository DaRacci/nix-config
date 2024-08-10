{ pkgs }: {
  ficsit-cli = pkgs.callPackage ./ficsit-cli { };
  noise-suppression = pkgs.callPackage ./noise-suppression-for-voice { };
  oscavmgr = pkgs.callPackage ./oscavmgr { };
  alvr = pkgs.callPackage ./alvr { };
  boxflat = pkgs.callPackage ./boxflat { };

  copy-to-proxmox = pkgs.callPackage ./copy-to-proxmox { };
  create-proxmox-container = pkgs.callPackage ./create-proxmox-container { };
}
