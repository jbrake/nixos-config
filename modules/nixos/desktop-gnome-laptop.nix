{
  lib,
  pkgs,
  ...
}:

# Full GNOME desktop for physical laptops. The GNOME VM remains intentionally
# lean and keeps its SPICE-specific scaling in desktop-gnome.nix.
let
  bluefinCoreExtensions = with pkgs.gnomeExtensions; [
    appindicator
    blur-my-shell
    dash-to-dock
    gsconnect
  ];
  productivityExtensions = with pkgs.gnomeExtensions; [
    caffeine
    clipboard-indicator
    tiling-shell
    vitals
  ];
  enabledExtensions = bluefinCoreExtensions ++ productivityExtensions;
  configuredExtensionSchemas = with pkgs.gnomeExtensions; [
    blur-my-shell
    dash-to-dock
  ];
  extensionSchemaPackage =
    extension:
    let
      packageName = "${extension.name}-gsettings-schemas";
      sourceDirectory = "${extension}/share/gnome-shell/extensions/${extension.extensionUuid}/schemas";
    in
    pkgs.runCommand packageName { } ''
      schemaDirectory="$out/share/gsettings-schemas/${packageName}/glib-2.0/schemas"
      mkdir -p "$schemaDirectory"
      for schema in ${sourceDirectory}/*.xml; do
        ln -s "$schema" "$schemaDirectory/$(basename "$schema")"
      done
    '';
  extensionSchemaPackages = map extensionSchemaPackage configuredExtensionSchemas;
  enabledExtensionUuids = lib.concatMapStringsSep ", " (
    extension: "'${extension.extensionUuid}'"
  ) enabledExtensions;
in
{
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome = {
    enable = true;

    # Bluefin-inspired, user-overridable defaults adapted for this machine.
    # Upstream source (Apache-2.0), reviewed 2026-07-11:
    # https://github.com/projectbluefin/common/blob/ed4aa87ad93b1e5ae2501d5b62a8dc5063c45a52/system_files/bluefin/usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override
    extraGSettingsOverridePackages = [
      pkgs.gnome-settings-daemon
      pkgs.gtk3
      pkgs.gtk4
      pkgs.mutter
      pkgs.nautilus
    ]
    ++ extensionSchemaPackages;
    extraGSettingsOverrides = ''
      [org.gnome.shell]
      favorite-apps=['brave-browser.desktop', 'org.gnome.Nautilus.desktop', 'com.mitchellh.ghostty.desktop', 'discord.desktop', 'steam.desktop']
      enabled-extensions=[${enabledExtensionUuids}]

      [org.gnome.desktop.interface]
      enable-hot-corners=false
      clock-show-weekday=true
      show-battery-percentage=true
      accent-color='purple'

      [org.gnome.desktop.wm.preferences]
      button-layout=':minimize,maximize,close'
      num-workspaces=4

      [org.gnome.desktop.wm.keybindings]
      show-desktop=['<Super>d']
      switch-applications=['<Super>Tab']
      switch-applications-backward=['<Shift><Super>Tab']
      switch-windows=['<Alt>Tab']
      switch-windows-backward=['<Shift><Alt>Tab']
      unmaximize=['<Super>Down']

      [org.gnome.settings-daemon.plugins.media-keys]
      home=['<Super>e']

      [org.gnome.mutter]
      center-new-windows=true

      [org.gtk.Settings.FileChooser]
      sort-directories-first=true

      [org.gtk.gtk4.Settings.FileChooser]
      sort-directories-first=true

      [org.gnome.nautilus.preferences]
      default-folder-viewer='list-view'

      [org.gnome.shell.extensions.dash-to-dock]
      dock-position='BOTTOM'
      dock-fixed=true
      force-straight-corner=false
      custom-theme-shrink=true
      disable-overview-on-startup=true
      transparency-mode='DYNAMIC'
      animation-time=0.15
      background-color='rgb(40,40,40)'
      background-opacity=0.8
      custom-background-color=true
      customize-alphas=true
      max-alpha=0.8
      min-alpha=0.5
      running-indicator-style='DOTS'
      apply-custom-theme=true

      [org.gnome.shell.extensions.blur-my-shell.dash-to-dock]
      blur=true

      [org.gnome.shell.extensions.blur-my-shell.popup]
      blur=false

      # Match the existing Plasma touchpad behavior. GNOME has no supported
      # equivalent to Plasma's independent ScrollFactor=0.3 setting.
      [org.gnome.desktop.peripherals.touchpad]
      tap-to-click=false
      tap-and-drag=false
      natural-scroll=true
      disable-while-typing=false
      click-method='fingers'
      two-finger-scrolling-enabled=true
    '';
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };

  xdg.terminal-exec = {
    enable = true;
    settings = {
      default = [ "com.mitchellh.ghostty.desktop" ];
      GNOME = [ "com.mitchellh.ghostty.desktop" ];
    };
  };

  environment.gnome.excludePackages = with pkgs; [
    epiphany
    gnome-tour
  ];

  environment.systemPackages =
    with pkgs;
    [
      gnome-extension-manager
      gnome-tweaks
    ]
    ++ enabledExtensions;

  # GSConnect implements the KDE Connect protocol without running the KDE
  # daemon. These are the same ranges opened by NixOS's KDE Connect module.
  networking.firewall.allowedTCPPortRanges = [
    {
      from = 1714;
      to = 1764;
    }
  ];
  networking.firewall.allowedUDPPortRanges = [
    {
      from = 1714;
      to = 1764;
    }
  ];
}
