{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  cfg = config.jbrake.resticBackup;
  jobName = "${cfg.user}-home";
  serviceName = "restic-backups-${jobName}";
  failureServiceName = "restic-backup-failure-${jobName}";
in
{
  options.jbrake.resticBackup = {
    enable = lib.mkEnableOption "encrypted home backups to the Synology NAS";

    user = lib.mkOption {
      type = lib.types.str;
      default = username;
      description = "Local user whose home directory is backed up.";
    };

    nasHost = lib.mkOption {
      type = lib.types.str;
      default = "10.69.1.164";
      description = "Synology hostname or stable LAN address.";
    };

    nasUser = lib.mkOption {
      type = lib.types.str;
      description = "Dedicated Synology SFTP account for this backup.";
    };

    nasShare = lib.mkOption {
      type = lib.types.str;
      description = "SFTP-visible Synology shared folder for this backup.";
    };

    passwordFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/secrets/restic-password";
      description = "Root-readable file containing the Restic repository password.";
    };

    sshKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/secrets/restic-ssh-key";
      description = "Root-readable SSH private key for the Synology SFTP account.";
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "/home/${cfg.user}/.cache"
        "/home/${cfg.user}/.local/share/Trash"
        "/home/${cfg.user}/.local/state/home-manager"
        "/home/${cfg.user}/.local/state/nix"
        # Re-downloadable Steam content. Keep userdata, config, screenshots,
        # and compatdata because Proton prefixes may contain non-cloud saves.
        "/home/${cfg.user}/.local/share/Steam/steamapps/common"
        "/home/${cfg.user}/.local/share/Steam/steamapps/downloading"
        "/home/${cfg.user}/.local/share/Steam/steamapps/shadercache"
        "/home/${cfg.user}/.local/share/Steam/steamapps/temp"
        "/home/${cfg.user}/.local/share/Steam/steamapps/workshop"
      ];
      description = "Restic exclusion patterns for reproducible or disposable home data.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Public host identity captured directly from the NAS. Keeping this in Git
    # lets unattended backups verify that they reached the expected server.
    programs.ssh.knownHosts.synology-restic = {
      hostNames = [ cfg.nasHost ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOH23DBozgUWp/8NRyvCIC6THkhI/wV6QuY7Hp5LL8Ra";
    };

    services.restic.backups.${jobName} = {
      initialize = true;
      repository = "sftp:${cfg.nasUser}@${cfg.nasHost}:/${cfg.nasShare}";
      inherit (cfg) passwordFile;
      paths = [ "/home/${cfg.user}" ];
      inherit (cfg) exclude;

      extraOptions = [
        "sftp.command='ssh ${cfg.nasUser}@${cfg.nasHost} -i ${cfg.sshKeyFile} -o IdentitiesOnly=yes -s sftp'"
      ];
      extraBackupArgs = [ "--exclude-caches" ];

      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
      inhibitsSleep = true;

      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
        "--keep-yearly 3"
      ];
      runCheck = true;
      # The normal structural check is inexpensive. Reading a random 5% of
      # stored data each run also detects damaged pack contents over time.
      checkOpts = [
        "--with-cache"
        "--read-data-subset=5%"
      ];
    };

    systemd.services.${serviceName}.onFailure = [ "${failureServiceName}.service" ];

    # Report scheduled failures in the journal, logged-in terminals, and the
    # user's graphical session when one is available.
    systemd.services.${failureServiceName} = {
      description = "Notify ${cfg.user} that the Restic backup failed";
      serviceConfig.Type = "oneshot";
      script = ''
        message="Restic backup ${jobName} failed. Check: journalctl -u ${serviceName}.service"
        echo "$message"
        ${pkgs.util-linux}/bin/wall -n "$message" || true

        uid="$(${pkgs.coreutils}/bin/id -u ${lib.escapeShellArg cfg.user})"
        if [[ -S "/run/user/$uid/bus" ]]; then
          ${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg cfg.user} -- \
            ${pkgs.coreutils}/bin/env \
              XDG_RUNTIME_DIR="/run/user/$uid" \
              DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
              ${pkgs.libnotify}/bin/notify-send \
                --app-name="Restic" --urgency=critical \
                "Backup failed" "$message" || true
        fi
      '';
    };
  };
}
