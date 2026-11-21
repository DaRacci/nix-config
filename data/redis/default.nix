{ dataLib }:
{
  data.mappings = builtins.fromJSON (builtins.readFile ./mappings.json);

  validate =
    lib: data:
    let
      ids = lib.attrValues data.redis.mappings;
    in
    dataLib.unique { values = ids; }
    ++ dataLib.range {
      min = 0;
      max = 15;
      values = ids;
    };
}
