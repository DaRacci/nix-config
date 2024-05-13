{ writeShellApplication
, openssh
, lib
, pkgs
}: writeShellApplication {
  name = "copy-to-proxmox";

  runtimeInputs = [ openssh ];

  text = ''
    TARGET="''${1}"
    if [ -z "$TARGET" ]; then
      echo "No target specified"
      exit 1
    fi

    nix build .#"''${TARGET}" --impure

    echo "Adding result to proxmox templates"
    scp -oIdentitiesOnly=yes result root@192.168.2.210:/var/lib/vz/template/cache/"''${TARGET}"-${pkgs.stdenv.system}.tar.gz
  '';

  meta = {
    description = "Copy a hosts output to proxmox templates";
    license = lib.licenses.MIT;
    platforms = lib.platforms.linux;
    maintainers = [ "DaRacci" ];
  };
}
