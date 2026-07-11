_:

# Full COSMIC desktop for physical laptops. Keep the VM-specific COSMIC role
# separate so this profile can inherit the shared workstation application set.
{
  services.displayManager.cosmic-greeter.enable = true;
  services.desktopManager.cosmic.enable = true;

  xdg.portal.xdgOpenUsePortal = true;

  xdg.terminal-exec = {
    enable = true;
    settings = {
      default = [ "com.mitchellh.ghostty.desktop" ];
      COSMIC = [ "com.mitchellh.ghostty.desktop" ];
    };
  };
}
