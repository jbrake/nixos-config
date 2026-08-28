{
  inputs,
  username,
  ...
}:

{
  imports = [
    ./desktop-plasma.nix
    inputs.nixarchy.nixosModules.nixarchy
  ];

  # Nixarchy is an additional session, not a replacement for Plasma or SDDM.
  services.displayManager = {
    defaultSession = "plasma";
    sddm.theme = "breeze";
  };

  programs.nixarchy = {
    enable = true;
    displayManager = false;

    # Jason already declares applications and shell behavior in this flake.
    preinstalls = false;
    bashIntegration = false;
    shellIntegration = false;

    # This flake owns packages and has multiple host outputs. Keep upstream's
    # package mutation and system-update actions out of the desktop menu while
    # retaining themes, plugins, setup, and other user-level actions.
    menu.extraEntries = {
      install.when = "false";
      remove.when = "false";
      "update.omarchy".when = "false";
    };
  };

  # Preserve existing system policy unrelated to the additional session.
  boot.plymouth.enable = false;
  services.locate.enable = false;
  virtualisation.docker.enable = false;

  home-manager.users.${username} = { lib, ... }: {
    imports = [ inputs.nixarchy.homeManagerModules.nixarchy ];
    programs.nixarchy.enable = true;

    # Nixarchy already seeds mutable Omarchy configuration. Skip Omarchy's
    # Arch first-login orchestration afterwards: it maps XDG Desktop to $HOME,
    # making Plasma display the entire home as icons, and tries to enable user
    # units that Nixarchy does not install on NixOS.
    home.activation.nixarchyProvisioned = lib.hm.dag.entryAfter [ "nixarchySeed" ] ''
      run mkdir -p "$HOME/.local/state/omarchy/done"
      run touch \
        "$HOME/.local/state/omarchy/done/finalize-user" \
        "$HOME/.local/state/omarchy/done/first-run-user"
    '';
  };
}
