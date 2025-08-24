{ config, lib, pkgs, ... }:

with lib;

{
  options.desktops.gnome = {
    enable = mkEnableOption "GNOME desktop environment";
  };

  config = mkIf config.desktops.gnome.enable {
    # Core GNOME services
    services.xserver.enable = true;
    services.displayManager.gdm = {
      enable = true;
      wayland = true;  # Enable Wayland by default for better fractional scaling
    };
    services.desktopManager.gnome.enable = true;
    
    # Input configuration
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    # Enable essential system services for GNOME
    programs.dconf.enable = true;
    services.udev.packages = with pkgs; [ gnome-settings-daemon ];
    programs.seahorse.enable = true;  # Keyring management
    services.gnome.gnome-keyring.enable = true;
    
    # Qt integration for better app theming
    qt = {
      enable = true;
      platformTheme = "gnome";
      style = "adwaita-dark";
    };
    
    # Font configuration
    fonts.packages = with pkgs; [
      cantarell-fonts
      source-code-pro
      noto-fonts
      noto-fonts-emoji
    ];
    
    # Fix cursor and theme issues
    environment.variables = {
      # Cursor configuration
      XCURSOR_THEME = "Adwaita";
      XCURSOR_SIZE = "24";
      # GTK theme consistency
      GTK_THEME = "Adwaita:dark";
      # Fix Java applications
      _JAVA_AWT_WM_NONREPARENTING = "1";
      # Better Wayland support
      MOZ_ENABLE_WAYLAND = "1";
      NIXOS_OZONE_WL = "1";
    };
    
    # Essential GNOME packages
    environment.systemPackages = with pkgs; [
      # Core GNOME tools
      gnome-tweaks
      gnome-extension-manager
      dconf-editor
      
      # Essential extensions
      gnomeExtensions.appindicator
      gnomeExtensions.dash-to-dock
      gnomeExtensions.blur-my-shell
      gnomeExtensions.just-perfection
      
      # Themes and icons
      adwaita-icon-theme
      gnome-themes-extra
      papirus-icon-theme
      
      # GTK libraries
      gtk3
      gtk4
      
      # Multimedia support
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly
      
      # File management
      file-roller  # Archive manager
      
      # Development tools that work well with GNOME
      vscode
    ];

    # Remove unwanted GNOME applications
    environment.gnome.excludePackages = with pkgs; [
      # Web browsers (user will likely install their preferred one)
      epiphany
      
      # Email client
      geary
      
      # Other apps that users may not need
      gnome-tour
      gnome-music
      gnome-photos
      simple-scan
      totem  # Video player
      yelp   # Help viewer
    ];

    # Declarative dconf configuration for system defaults
    programs.dconf.profiles.user.databases = [{
      settings = {
        # Enable experimental features for fractional scaling and performance
        "org/gnome/mutter" = {
          experimental-features = [
            "scale-monitor-framebuffer"  # Fractional scaling
            "variable-refresh-rate"      # VRR support
            "xwayland-native-scaling"    # Better XWayland scaling
          ];
        };
        
        # Interface preferences
        "org/gnome/desktop/interface" = {
          enable-hot-corners = false;  # Disable hot corners by default
          show-battery-percentage = true;
        };
        
        # Window manager preferences
        "org/gnome/desktop/wm/preferences" = {
          button-layout = "appmenu:minimize,maximize,close";  # Standard layout
        };
        
        # Privacy settings
        "org/gnome/desktop/privacy" = {
          report-technical-problems = false;
          send-software-usage-stats = false;
        };
        
        # Power settings
        "org/gnome/settings-daemon/plugins/power" = {
          sleep-inactive-ac-type = "nothing";  # Don't suspend when plugged in
        };
      };
    }];

    # Enable location services (optional, for automatic timezone)
    services.geoclue2.enable = true;
    
    # Enable CUPS for printing
    services.printing.enable = true;
    
    # Enable sound
    hardware.pulseaudio.enable = false;  # Conflicts with pipewire
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}