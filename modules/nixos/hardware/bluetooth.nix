{ config, lib, ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.hardware.bluetooth;
in
{
  options.hardware.bluetooth = {
    disabledDevices = mkOption {
      type = with lib.types; listOf (submodule {
        options = {
          vendorId = mkOption {
            type = str;
            description = "The vendor ID of the device to disable.";
          };

          productId = mkOption {
            type = str;
            description = "The product ID of the device to disable.";
          };
        };
      });
    };
  };

  config = mkIf cfg.enable {
    system.activationScripts = {
      rfkillUnblockBluetooth.text = ''
        rfkill unblock bluetooth
      '';
    };

    hardware.bluetooth.input = {
      General = {
        # Allows bluetooth battery level to be checked.
        Experimental = true;
      };
    };

    services = {
      blueman.enable = true;
      udev = {
        extraRules = ''
          # Disable bluetooth devices.
          ${lib.concatStringsSep "\n" (map (device: "SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"${device.vendorId}\", ATTRS{idProduct}==\"${device.productId}\", ATTR{authorized}=\"0\"") cfg.disabledDevices)}
        '';
      };
    };

    host.persistence.directories = [
      "/var/lib/bluetooth"
    ];
  };
}
