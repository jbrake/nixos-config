{ lib, username, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./nixarchy-apps.nix
  ];

  # Only the generated QEMU runner gets trial credentials and autologin.
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 8192;
      cores = 4;
      qemu.options = [ "-vga virtio" ];
      diskSize = 32768;
      diskImage = "./vm-nixarchy-trial.qcow2";
      resolution = {
        x = 1440;
        y = 900;
      };
    };
    # QEMU advertises a tiny preferred mode; select a usable desktop explicitly.
    home-manager.users.${username}.xdg.configFile."hypr/monitors.lua".text = ''
      hl.env("GDK_SCALE", "1")
      hl.monitor({ output = "", mode = "1440x900@60", position = "auto", scale = 1 })
    '';
    users.users.${username}.initialPassword = "nixarchy"; # gitleaks:allow -- public VM-only trial credential
    services.displayManager.autoLogin = {
      enable = true;
      user = username;
    };
    environment.sessionVariables = {
      WLR_RENDERER_ALLOW_SOFTWARE = "1";
      LIBGL_ALWAYS_SOFTWARE = "1";
    };
    boot.loader.systemd-boot.enable = lib.mkForce false;
  };
}
