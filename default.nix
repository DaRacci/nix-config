(import
  (
    let lock = builtins.fromJSON (builtins.readFile ./flake.lock); in
    fetchTarball {
      url = "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat-nixd.locked.rev}.tar.gz";
      sha256 = lock.nodes.flake-compat-nixd.locked.narHash;
    }
  )
  { src = ./.; }
).defaultNix
