{ lib }:
let
  simpleImport = path: import path { inherit lib; };
in
{
  mine = {
    attrsets = simpleImport ./attrsets.nix;
    files = simpleImport ./files.nix;
    hardware = simpleImport ./hardware.nix;

    mkPostgresRolePass = role: passPath: ''
      $PSQL -tA <<'EOF'
        DO $$
        DECLARE password TEXT;
        BEGIN
          password := trim(both from replace(pg_read_file('${passPath}'), E'\n', '''));
          EXECUTE format('ALTER USER ${role} WITH PASSWORD '''%s''';', password);
        END $$;
      EOF
    '';
  };
}
