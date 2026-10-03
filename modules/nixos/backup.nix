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
  successServiceName = "restic-backup-success-${jobName}";
  failureServiceName = "restic-backup-failure-${jobName}";
  # External USB Samsung 850 PRO (ext4, label "Backup").
  diskMount = "/mnt/backup";
in
{
  options.jbrake.resticBackup = {
    enable = lib.mkEnableOption "encrypted home backups to the external USB backup disk";

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
      description = "Root-readable SSH private key for the Synology SFTP account (NAS target only).";
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "/home/${cfg.user}/.cache"
        "/home/${cfg.user}/.local/share/Trash"
        "/home/${cfg.user}/.local/state/home-manager"
        "/home/${cfg.user}/.local/state/nix"
        "/home/${cfg.user}/Downloads"
        # ROM masters live on the NAS and are reproducible. Keep the adjacent
        # RetroDECK BIOS, saves, states, screenshots, and mutable configuration.
        "/home/${cfg.user}/retrodeck/roms"
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
    # NAS target disabled in favour of the external USB disk below. Uncomment
    # this, the NAS repository, and extraOptions to switch back.
    #
    # # Public host identity captured directly from the NAS. Keeping this in Git
    # # lets unattended backups verify that they reached the expected server.
    # programs.ssh.knownHosts.synology-restic = {
    #   hostNames = [ cfg.nasHost ];
    #   publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOH23DBozgUWp/8NRyvCIC6THkhI/wV6QuY7Hp5LL8Ra";
    # };

    # Automount rather than a plain mount so that, when the disk is unplugged,
    # restic fails against the autofs mount point instead of initializing a
    # fresh repository on the root filesystem. The idle timeout unmounts the
    # disk after a backup so it is safe to unplug.
    fileSystems.${diskMount} = {
      device = "/dev/disk/by-uuid/c93b20f8-c021-48b7-8942-da505215827f";
      fsType = "ext4";
      options = [
        "noauto"
        "nofail"
        # Lets the desktop mount it from the Devices panel without an admin
        # prompt. Implies noexec,nosuid,nodev, which suits a data disk.
        "users"
        "x-systemd.automount"
        "x-systemd.idle-timeout=5min"
        "x-systemd.device-timeout=10s"
      ];
    };

    # /mnt was created root-only (0700), which hid the mount point from the
    # user entirely. The repository inside stays root-owned and encrypted.
    systemd.tmpfiles.rules = [ "d /mnt 0755 root root -" ];

    services.restic.backups.${jobName} = {
      initialize = true;
      # repository = "sftp:${cfg.nasUser}@${cfg.nasHost}:/${cfg.nasShare}";
      repository = "${diskMount}/restic-${cfg.user}";
      inherit (cfg) passwordFile;
      paths = [ "/home/${cfg.user}" ];
      inherit (cfg) exclude;

      # extraOptions = [
      #   "sftp.command='ssh ${cfg.nasUser}@${cfg.nasHost} -i ${cfg.sshKeyFile} -o IdentitiesOnly=yes -s sftp'"
      # ];
      extraBackupArgs = [ "--exclude-caches" ];

      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
      inhibitsSleep = true;

      pruneOpts = [
        # Snapshots explicitly tagged "archive" survive the rolling policy.
        "--keep-tag archive"
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

    systemd.services.${serviceName} = {
      onSuccess = [ "${successServiceName}.service" ];
      onFailure = [ "${failureServiceName}.service" ];

      # Retry transient failures, such as the backup disk not being plugged in
      # yet (or, with the NAS target, Wi-Fi still reconnecting after resume),
      # but stop after roughly two hours so an absent target is not retried
      # forever.  RestartMode=direct suppresses
      # OnFailure notifications for the intermediate attempts; the notification
      # above is sent if the retry limit is ultimately exhausted.
      startLimitIntervalSec = 3 * 60 * 60;
      startLimitBurst = 12;
      serviceConfig = {
        Restart = "on-failure";
        RestartMode = "direct";
        RestartSec = "10min";
      };
    };

    # Report successful completion to the user's graphical session when one is
    # available. OnSuccess runs after the backup, retention, and check phases.
    systemd.services.${successServiceName} = {
      description = "Notify ${cfg.user} that the Restic backup completed";
      serviceConfig.Type = "oneshot";
      script = ''
        message="Restic backup ${jobName} completed successfully."
        echo "$message"

        uid="$(${pkgs.coreutils}/bin/id -u ${lib.escapeShellArg cfg.user})"
        if [[ -S "/run/user/$uid/bus" ]]; then
          ${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg cfg.user} -- \
            ${pkgs.coreutils}/bin/env \
              XDG_RUNTIME_DIR="/run/user/$uid" \
              DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
              ${pkgs.libnotify}/bin/notify-send \
                --app-name="Restic" --urgency=normal --expire-time=0 \
                "Backup complete" "$message" || true
        fi
      '';
    };

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
                --app-name="Restic" --urgency=critical --expire-time=0 \
                "Backup failed" "$message" || true
        fi
      '';
    };
  };
}
