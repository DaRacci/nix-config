{ lib }: rec {
  # Recursively constructs an attrset of a given folder, recursing on directories, value of attrs is the filetype
  getDir = dir: mapAttrs
    (file: type:
      if type == "directory" then getDir "${dir}/${file}" else type
    )
    (builtins.readDir dir);

  # Collects all files of a directory as a list of strings of paths
  files = dir: lib.collect lib.isString (lib.mapAttrsRecursive (path: _type: lib.concatStringsSep "/" path) (getDir dir));

  findFile = dir: pathPattern: lib.trivial.pipe (files dir) [
    (lib.filter (file: lib.hasSuffix pathPattern file))
    (builtins.map (file: ./. + "/${file}"))
    (arr: builtins.elemAt arr 0)
  ];
}
