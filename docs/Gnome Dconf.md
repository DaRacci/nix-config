## Description

When changing GNOME or GNOME extension settings, it is recommended to use dconf2nix and cherry pick its output. This allows for easy configuration using the GUI, but requires copying the settings back into the respective dconf settings in home-manager to save them.

---

## DConf Locations

The locations for where to save DConf settings to is:

-   [Base.nix](../home/shared/desktop/gnome/base.nix) for standard GNOME DConf Settings.
-   [Extensions.nix](../home/shared/desktop/gnome/extensions.nix) for Extensions DConf Settings
-   Per User Settings should be saved in the format of `home/${username}/desktop/gnome.nix`

---

## Getting the Output

dconf2nix will be installed as part of this flakes dev shell.

Running the following will output the current dconf settings into a temporary file so you can Cherry Pick your changes.

```sh
dconf dump / | dconf2nix > dconf.nix
```
