{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.mine.packages) writeNuApplicationWithLibs;

  sourceRoot = ./.;

  pki2kdbx = pkgs.writeShellApplication {
    name = "pki2kdbx";
    runtimeInputs = [
      (pkgs.python3.withPackages (ps: [ ps.cryptography ]))
      pkgs.keepassxc
    ];
    text = ''
      exec python3 ${./pki2kdbx.py} "$@"
    '';
  };
in
{
  inherit pki2kdbx;

  install-vale-dictionaries = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "install-vale-dictionaries";
    runtimeInputs = [ pkgs.ripgrep ];
  };

  vale-tech-dictionary =
    pkgs.runCommandLocal "vale-tech-dictionary"
      {
        CSPELL = pkgs.cspell;
        nativeBuildInputs = [
          pkgs.gzip
          pkgs.nushell
        ];
      }
      ''
        nu ${./vale-tech-dictionary.nu}
      '';

  nix-tree-host = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "nix-tree-host";
    runtimeInputs = [ pkgs.nix-tree ];
  };

  rebuild-target = writeNuApplicationWithLibs {
	inherit pkgs sourceRoot;
    name = "rebuild-target";
    runtimeInputs = [ pkgs.nh ];
  };

  update-redis-mappings = writeNuApplicationWithLibs {
	inherit pkgs sourceRoot;
    name = "update-redis-mappings";
    runtimeInputs = [ pkgs.lix ];
  };

  update-sops = writeNuApplicationWithLibs {
	inherit pkgs sourceRoot;
    name = "update-sops";
    runtimeInputs = [
      pkgs.sops
      pkgs.ssh-to-age
    ];
  };

  provision-alloy-certs = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "provision-alloy-certs";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.keepassxc
      pkgs.lix
      pkgs.openssl
      pkgs.sops
      pki2kdbx
    ];
  };

  provision-intermediate-ca = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "provision-intermediate-ca";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.keepassxc
      pkgs.openssl
      pki2kdbx
    ];
  };

  provision-db-guardian-certs = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "provision-db-guardian-certs";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.keepassxc
      pkgs.lix
      pkgs.openssl
      pkgs.sops
      pki2kdbx
    ];
  };

  build-changed = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "build-changed";
	runtimeInputs = [ pkgs.git ];
  };

  get-symbol-value = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "get-symbol-value";
  };

  module-graph = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "module-graph";
	runtimeInputs = [ pkgs.git ];
  };
}
