{ pkgs, ... }: {
	programs.xwayland.enable = true;

	xdg.portal = {
		enable = true;
		wlr.enable = true;
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

	environment.gnome.excludePackages = with pkgs; [
		gnome.epiphany
		gnome-tour
		gnome-text-editor
		gnome.gnome-calculator
		# gnome-connections
		gnome.simple-scan
		gnome.yelp
	];
}
