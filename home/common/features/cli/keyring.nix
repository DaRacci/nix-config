{
  services.gnome-keyring = {
    enable = true;
    components = [ "pkcs11" "ssh" ];
  };
}