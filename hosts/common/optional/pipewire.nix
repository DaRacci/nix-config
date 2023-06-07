{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [ noise-supression ];

  security.rtkit.enable = true;
  hardware.pulseaudio.enable = false;

  services.pipewire = {
    enable = true;
    alsa.enable = false;
    alsa.support32Bit = false;
    pulse.enable = true;
    jack.enable = false;
  };  
}