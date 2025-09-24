{ inputs, lib, ... }:
let
  simpleImport = path: import path { inherit inputs lib; };
in
{
  mine = {
    attrsets = simpleImport ./attrsets.nix;
    files = simpleImport ./files.nix;
    hardware = simpleImport ./hardware.nix;
    keys = simpleImport ./keys.nix;
    hypr = simpleImport ./hypr.nix;

    mkPostgresRolePass = role: passPath: ''
      psql -tA <<'EOF'
        DO $$
        DECLARE password TEXT;
        BEGIN
          password := trim(both from replace(pg_read_file('${passPath}'), E'\n', '''));
          EXECUTE format('ALTER USER "${role}" WITH PASSWORD '''%s''';', password);
        END $$;
      EOF
    '';
  };
}
