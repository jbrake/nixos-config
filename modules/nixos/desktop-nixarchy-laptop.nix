{ username, ... }:
{
  imports = [ ./desktop-nixarchy.nix ];

  # Keep package management and shell preferences in this repository. Upstream's
  # menu rebuilds infer the bare hostname, which selects our stable Plasma output.
  programs.nixarchy = {
    bashIntegration = false;
    shellIntegration = false;
    menu.extraEntries = {
      install.when = "false";
      remove.when = "false";
      "update.omarchy".when = "false";
    };
  };

  home-manager.users.${username} = { lib, ... }: {
    programs.nixarchy.neovim = "off";
    # Home Manager already provisions the session. The Arch first-login scripts
    # would also change shared XDG directories and application defaults.
    home.activation.nixarchyProvisioned = lib.hm.dag.entryAfter [ "nixarchySeed" ] ''
      run mkdir -p "$HOME/.local/state/omarchy/done"
      run touch "$HOME/.local/state/omarchy/done/finalize-user" \
        "$HOME/.local/state/omarchy/done/first-run-user"
    '';
  };
}
