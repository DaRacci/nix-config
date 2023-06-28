{
  containers.prometheus = {
    inherit (import ../common);

    config = { ... }: {
      services.prometheus = {

      };
    };
  };
}