{ v }:
{
  data = {
    domain = "racci.dev";
    adminEmail = "admin@racci.dev";
  };

  validate =
    lib: data:
    v.keys {
      expected = [
        "domain"
        "adminEmail"
      ];
      actual = builtins.attrNames data.site;
    }
    ++ [
      {
        assertion = data.site.domain != "";
        message = "domain must not be empty";
      }
      {
        assertion = lib.hasInfix "@" data.site.adminEmail;
        message = "adminEmail must contain @";
      }
    ];
}
