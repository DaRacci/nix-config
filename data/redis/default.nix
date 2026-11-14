{ v }:
{
  data.mappings = builtins.fromJSON (builtins.readFile ./mappings.json);

  validate =
    lib: data:
    let
      ids = lib.attrValues data.redis.mappings;
    in
    v.unique { values = ids; }
    ++ v.range {
      min = 0;
      max = 15;
      values = ids;
    };
}
