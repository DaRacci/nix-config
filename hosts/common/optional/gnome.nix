{ pkgs, lib, ... }: {
	programs.xwayland.enable = true;

	xdg.portal = {
		enable = lib.mkForce false;
    # xdgOpenUsePortal = true;
    # extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
	};

	services.xserver = {
		enable = true;

		displayManager.gdm = {
			enable = true;
			wayland = true;
		};

		desktopManager.gnome = {
			enable = true;
		};
	};

  services.gnome = {
    gnome-browser-connector.enable = true;
    sushi.enable = true;
  };

	environment.gnome.excludePackages = with pkgs; [
		gnome-tour
		gnome-text-editor
		gnome.gnome-calculator
		# gnome-connections
		gnome.simple-scan
		gnome.yelp
	];
}
