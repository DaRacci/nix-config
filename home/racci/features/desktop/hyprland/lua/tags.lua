-- Tags for categories of programs.
-- No actual rules are applied here only tags which are then consumed to create rules.

require("helpers.windows")
require("helpers.workspaces")

--- A table of tags with the value being the hyprland tag name.
--- @enum Tags
local Tags = {
  assistant = "assistant",
  terminal = "terminal",
  browser = "browser",
  files = "files",
  knowledge = "knowledge",
  chat = "chat",
  media = "media",
  office = "office",
  code = "code",
  developmentUtility = "development-utility",
  game = "game",
  gameLauncher = "game-launcher",
  gameUtility = "game-utility",
  design = "design",
  sensitive = "sensitive",
  system = "system",
  remote = "remote",
  child = "child",
  diaglogueModal = "dialogue-modal",
  barDropdown = "bar-dropdown",
  contextMenu = "context-menu",
  pictureInPicture = "picture-in-picture",
  -- Windows tagged with this are useless to be sent to a void workspace and not seen by the user.
  silentBullshit = "silent-bullshit",
}

TagByMatch(Tags.assistant, {
  Class("hermes"),
})

TagByMatch(Tags.terminal, {
  Class("Alacritty"),
})

TagByMatch(Tags.browser, {
  Class("firefox"),
  Class("chromium"),
  Class("google-chrome"),
})

TagByMatch(Tags.files, {
  Class("gnome-disks"),
  Class("org.gnome.baobab"),
  Class("org.gnome.Nautilus"),
  Class("org.gnome.FileRoller"),
  Class("de.haeckerfelix.Fragments"),
  Class("io.gitlab.adhami3310.Impression"),
  Class("com.nextcloud.desktopclient.nextcloud"),
})

TagByMatch(Tags.knowledge, {
  Class("md.obsidian"),
  Class("io.gitlab.news_flash.NewsFlash"),
  Class("com.github.hugolabe.wike"),
})

TagByMatch(Tags.chat, {
  Class("discord"),
  Class("teams-for-linux"),
  Class("org.gnome.polari"),
  Class("dev.geopjr.Tuba"),
  Class("com.nextcloud.talk"),
})

TagByMatch(Tags.media, {
  Class("mpv"),
  Class("com.obsproject.Studio"),
  Class("org.gnome.Loupe"),
  Class("org.gnome.Decibels"),
  Class("feishin"),
  Class("org.musicbrainz.Picard"),
  Class("com.belmoussaoui.Obfuscate"),
  Class("io.gitlab.adhami3310.Footage"),
  Class("org.nickvision.tubeconverter"),
  Class("moe.tsuna.tsukimi"),
  Class("fr.handbrake.ghb"),
})

TagByMatch(Tags.office, {
  Class("org.gnome.Calendar"),
  Class("org.gnome.Calculator"),
  Class("org.gnome.Contacts"),
  Class("org.gnome.Papers"),
  Class("libreoffice-*"),
  Class("proton-mail"),
})

TagByMatch(Tags.code, {
  Class("code"),
  Class("dev.zed.Zed"),
  Class("org.gnome.Meld"),
})

TagByMatch(Tags.developmentUtility, {
  Class("net.ffkkinos.Wildcard"),
  Class("io.gitlab.liferooter.TextPieces")
})

TagByMatch(Tags.game, {
  Class("steam_app_[0-9]{1,8}", {}, false),
  Class("dwarfort"),
  Class("gamescope"),
  Class("osu!"),
  -- If a window is on the workspace and fullscreened, it is most likely a game and should be tagged as such.
  {
    workspace = NamedWorkspaces.game,
    fullscreen = true,
    focus = true,
  }
})

TagByMatch(Tags.gameLauncher, {
  Class("steam"),
  Title("Lutris"),
  Class("com.heroicgameslauncher.hgl"),
})

TagByMatch(Tags.gameUtility, {
  Class("steamwebhelper"),
  Class("SideQuest"),
  Class("r2modman"),
  Class("bs-manager"),
  Class("io.github.lawstorant.boxflat"),
})

TagByMatch(Tags.design, {
  Class("gimp"),
  Class("org.freecad.FreeCAD"),
  Class("MeshLab_64bit_fp"),
  Class("kicad"),
  Class("orcaslicer"),
  Class("lycheeslicer"),
  Class("Uvtools"),
})

TagByMatch(Tags.sensitive, {
  Class("1password"),
  Class("bitwarden"),
  Class("org.keepassxc.KeePassXC"),
})

TagByMatch(Tags.system, {
  Class("net.nokyan.Resources"),
  Class("com.github.wwmm.easyeffects"),
  Class("com.core447.StreamController"),
  Class("org.pulseaudio.pavucontrol"),
  Class("blueman-manager"),
  Class("nvidia-settings"),
  Class("qt5ct"),
  Class("qt6ct"),
  Class("org.x.GnomeOnlineAccountsGtk"),
  Class("org.gnome.Maps"),
  Class("org.freedesktop.Bustle"),
  Class("vial"),
  Class("wootility"),
  Class("kopia-ui"),
})

TagByMatch(Tags.remote, {
  Class("takecontrolrdviewer.exe"),
  Class(".virt-manager-wrapped"),
})

TagByMatch(Tags.child, {
  Class("discord", { initial_title = "Discord popout" }),
  Class("dev.zed.Zed", { initial_title = "Zed — Settings" }),
  Class("md.Obsidian", { initial_title = "negative:Obsidian" }),
  Title("Picture-in-Picture"),
})

TagByMatch(Tags.diaglogueModal, {
  Title("Authentication Required"),
  Title("Select what to share"),
  Class("file_progress"),
  Class("confirm"),
  Class("dialog"),
  Class("download"),
  Class("notification"),
  Class("error"),
  Class("confirmreset"),
  Title("branchdialog"),
  Title("Confirm to replace files"),
  Title("File Operation Progress"),
  Title("About"),
  Title("^(Open File)(.*)$", {}, false),
  Title("^(Select a File)(.*)$", {}, false),
  Title("^(Open Folder)(.*)$", {}, false),
  Title("^(Save As)$", {}, false),
  Title("^(Library)(.*)$", {}, false),
  Title("^(File Upload)(.*)$", {}, false),
  Title("(?i)^(.*)(wants to save)$"),
  -- This is the 1password access requested window.
  -- The primary window is never titled as 1Password.
  Title("1Password"),
  Title("Quick Access — 1Password")
})

TagByMatch(Tags.barDropdown, {
  Class("org.pulseaudio.pavucontrol"),
  Class(".blueman-manager-wrapped")
})

TagByMatch(Tags.contextMenu, {
  -- Matches xwayland context menus.
  {
    class = "^()$",
    title = "^()$",
    xwayland = true
  }
})

local pipRegex = "^(?i)(picture[-\\s]?in[-\\s]?picture)(.*)$"
TagByMatch(Tags.pictureInPicture, {
  Title(pipRegex, {}, false),
  Class(pipRegex, {}, false),
})

TagByMatch(Tags.silentBullshit, {
  { initial_title = "(@takeControlConnectingTitleRegex@)$" }
})

_G.Tags = Tags
return Tags
