{ lib }: rec {
  # Recursively constructs an attrset of a given folder, recursing on directories, value of attrs is the filetype
  getDir = dir: mapAttrs
    (file: type:
      if type == "directory" then getDir "${dir}/${file}" else type
    )
    (builtins.readDir dir);

  # Collects all files of a directory as a list of strings of paths
  files = dir: lib.collect lib.isString (lib.mapAttrsRecursive (path: _type: lib.concatStringsSep "/" path) (getDir dir));

  /*
    Find a file in a directory by its path pattern, return the first match.
    If no file is found, throw an error.
  */
  findFile = dir: pathPattern: lib.trivial.pipe (files dir) [
    (lib.filter (file: lib.hasSuffix pathPattern file))
    (builtins.map (file: ./. + "/${file}"))
    (arr: builtins.elemAt arr 0)
  ];

  /*
    Collect all files ending with .nix of a directory as a list of strings of paths,
    excluding default.nix.

    Usage:
      imports = (getModules ./someDir);
  */
  getModules = dir: trivial.pipe (files dir) [
    (lib.filter (file: lib.hasSuffix ".nix" file))
    (lib.filter (file: ! lib.hasSuffix "default.nix" file))
    (builtins.map (file: ./. + "/${file}"))
  ];
}
