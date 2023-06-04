{ config, pkgs, ... }:

{
  home.persistence."/persist/home/${config.home.username}".directories = [
    ".config/Code/User"
  ];

	home.packages = with pkgs; [
		(vscode-with-extensions.override {
			vscodeExtensions = with vscode-extensions; [
				# LSP Support
				rust-lang.rust-analyzer
				jnoortheen.nix-ide

				# File Support
				redhat.vscode-yaml
				redhat.vscode-xml
				matthewpi.caddyfile-support
				coolbear.systemd-unit-file

				# Formatters
				esbenp.prettier-vscode
				editorconfig.editorconfig

				# Container Tools
				ms-kubernetes-tools.vscode-kubernetes-tools
				ms-azuretools.vscode-docker
				
				# GUI related
				pkief.material-icon-theme
				piousdeer.adwaita-theme
				naumovs.color-highlight

				# Other
				github.copilot
				christian-kohler.path-intellisense
				alefragnani.project-manager
			] ++ vscode-utils.extensionsFromVscodeMarketplace [
				{
					name = "better-comments";
					publisher = "aaron-bond";
					version = "3.0.0"; # TODO :: Any way to automate updates?
					sha256 = "sha256-bosv8zfta3TCskgmTqPWlPFX2fPGvq+QdnE58EGpZ50=";
				}
			];
		})
	];
}
