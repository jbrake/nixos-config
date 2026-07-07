{ pkgs, ... }:

# COSMIC desktop for the vm-cosmic guest — tracking System76's DE as it
# develops. Expect churn; that's the point of watching it from a VM.
{
  services.displayManager.cosmic-greeter.enable = true;
  services.desktopManager.cosmic.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  hardware.graphics.enable = true;

  # brave matches the BROWSER/mime defaults in home.nix, ghostty the
  # TERMINAL default. COSMIC brings its own terminal/files/editor.
  environment.systemPackages = with pkgs; [
    brave
    ghostty
  ];
}
