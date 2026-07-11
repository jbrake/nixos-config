{
  desktop,
  pkgs,
  username,
  ...
}:

let
  home = "/home/${username}";
  activateDesktopState = pkgs.writeShellApplication {
    name = "activate-desktop-state";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
    ];
    text = ''
      exec ${pkgs.bash}/bin/bash ${../../scripts/desktop-state-activate.sh} \
        ${desktop} ${home} ${username} users
    '';
  };
in
{
  assertions = [
    {
      assertion = builtins.elem desktop [
        "plasma"
        "gnome"
        "cinnamon"
        "cosmic"
      ];
      message = "Unsupported laptop desktop state capsule: ${desktop}";
    }
  ];

  environment.systemPackages = [ activateDesktopState ];

  # Runs on boot before either Home Manager or the display manager can read
  # desktop state. RemainAfterExit plus restartIfChanged=false prevents a live
  # nixos-rebuild switch from moving files underneath a running session.
  systemd.services.desktop-state-activate = {
    description = "Activate the saved ${desktop} desktop state";
    wantedBy = [ "multi-user.target" ];
    before = [
      "display-manager.service"
      "home-manager-${username}.service"
    ];
    restartIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${activateDesktopState}/bin/activate-desktop-state";
    };
  };

  systemd.services."home-manager-${username}" = {
    after = [ "desktop-state-activate.service" ];
    requires = [ "desktop-state-activate.service" ];
  };

  # Fail closed: if a capsule cannot be activated, leave the graphical login
  # stopped so the user can inspect the journal from a TTY without allowing
  # one desktop to write into the other desktop's state.
  systemd.services.display-manager = {
    after = [ "desktop-state-activate.service" ];
    requires = [ "desktop-state-activate.service" ];
  };
}
