# { config, lib }:

# with lib; let
#   cfg = config.containers.podman-runner;
#   user = "podman-runner";
# in {
#   options.containers = {
#     enable = mkEnableOption "containers";

#     reverse-proxy = {
#       enable = mkOption {
#         type = types.bool;
#         default = false;
#       };

#       provider = mkOption {
#         type = types.str;
#         default = "traefik";
#       };
#     }
#   };

#   config = mkIf cfg.enable {
#     virtualisation.oci-containers.backend = "podman";

#     virtualisation.podman = {
#       enable = true;

#       defaultNetwork.dnsname.enable = true;

#       # TODO: Check for nvidia gpu
#       enableNvidia = true;
#       dockerCompat = false;

#       networkSocket = {
#         enable = false; # TODO?
#         listenAddress = "0.0.0.0";
#       };

#       autoPrune = {
#         enable = true;
#         dates = "weekly";
#         flags = [ ];
#       };
#     };
#   };

#   meta = {
#     maintainers = with lib.maintainers; [ racci ];
#   };
# }
