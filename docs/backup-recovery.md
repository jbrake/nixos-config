# Restic Backup and Recovery

Jason's home directory is backed up daily to an encrypted Restic repository on
the Synology NAS. NixOS configures the job; two root-only secrets provide
access.

## Quick Reference

These commands assume the configured NixOS system and both
[required secrets](#required-secrets) are available. Always choose an explicit
snapshot ID before restoring. This matters during the AMD-to-Intel replacement
because both laptops use the same repository.

### Make a backup now

```bash
sudo systemctl start restic-backups-jason-home.service
sudo restic-jason-home snapshots --host "$(hostname)" --latest 1
```

The first command waits for the backup, retention pass, and repository check to
finish. It can take several minutes and normally prints nothing while it runs.
Follow progress from another terminal if wanted:

```bash
journalctl -fu restic-backups-jason-home.service
```

### Choose and inspect a snapshot

```bash
sudo restic-jason-home snapshots --group-by host,paths
sudo restic-jason-home ls SNAPSHOT_ID /home/jason/Documents --recursive
sudo restic-jason-home find --host framework-amd-ai-300 example.txt
```

The first command shows the snapshot ID, time, source host, and backed-up path.
`ls` browses one chosen snapshot. `find` searches available versions of a lost
file; replace the hostname when searching snapshots from a different system.

### Restore one or several paths

Restore into a unique temporary directory, inspect the result, and then copy it
into place:

```bash
restore_dir="$(mktemp -d /tmp/restic-restore.XXXXXX)"
sudo restic-jason-home restore SNAPSHOT_ID \
  --target "$restore_dir" \
  --include /home/jason/Documents/example.txt \
  --include /home/jason/Pictures/example-directory
sudo ls -l "$restore_dir/home/jason/Documents/example.txt"
sudo rsync -aHAX --numeric-ids \
  "$restore_dir/home/jason/Documents/example.txt" \
  /home/jason/Documents/
sudo rm -rf -- "$restore_dir"
```

Repeat `--include` for each wanted file or directory. Omit the second example
when restoring only one path. Copy only the inspected paths back into the home
directory; the `rsync` example preserves ownership and metadata.

### Restore all backed-up home files

Use [Restore the Entire Home on the Current Installation](#restore-the-entire-home-on-the-current-installation)
for a working system, or [Full Recovery on a Fresh Installation](#full-recovery-on-a-fresh-installation)
after replacing a disk or laptop. Both workflows restore into a staging
directory first. Do not point Restic directly at `/home/jason`.

## Configuration

```text
source:      /home/jason
repository:  sftp:restic-jason@10.69.1.164:/restic-jason
checkout:    /home/jason/Documents/repos/nixos-config
schedule:    daily, with missed runs started after boot or resume
retention:   7 daily, 5 weekly, 12 monthly, 3 yearly
protected:   snapshots tagged archive
```

The backup includes documents, all five desktop state capsules, Brave profiles
and extensions, PrismLauncher instances and Minecraft worlds, Codex sessions,
SSH keys, desktop credential stores, and other files under `/home/jason`.

Desktop capsules and Restic serve different purposes. Capsules automatically
preserve each desktop's latest local state during switching; Restic keeps
historical home snapshots on the NAS for reinstallations and disaster recovery.
See [Switching Desktop Environments](desktop-switching.md) for the short workflow.

It excludes:

```text
~/.cache
~/.local/share/Trash
~/.local/state/home-manager
~/.local/state/nix
~/retrodeck/roms (canonical ROM library is stored separately on the NAS)
Steam game downloads, Workshop content, and shader caches
directories marked with CACHEDIR.TAG
```

RetroDECK BIOS files, saves, save states, screenshots, and mutable emulator
configuration are kept. Ryubing's private keys, installed Switch firmware,
saves, and configuration below `~/.var/app/io.github.ryubing.Ryujinx` are kept
as well. Steam settings, screenshots, `userdata`, and Proton `compatdata` are
also kept.
System libvirt VMs under `/var/lib/libvirt` are not backed up. Applications may
ask you to sign in again after a restore.

## Required Secrets

```text
/var/lib/secrets/restic-password   decrypts the Restic repository
/var/lib/secrets/restic-ssh-key    connects to the NAS
```

The Restic password is irreplaceable. Keep it somewhere outside the laptop.
The SSH key is replaceable through a Synology administrator account.

Neither secret belongs in Git. The NixOS config, NAS address, account name, and
public SSH keys are safe in a public repository.

## Maintenance Commands

Check snapshots, the timer, or recent output:

```bash
sudo restic-jason-home snapshots
systemctl list-timers restic-backups-jason-home.timer --all
journalctl -u restic-backups-jason-home.service --since yesterday
```

Run an explicit repository check:

```bash
sudo restic-jason-home check
```

Protect an important snapshot from the rolling retention policy:

```bash
sudo restic-jason-home tag --add archive SNAPSHOT_ID
```

Use this for deliberate transition points, not routine daily snapshots.

Every scheduled or manually started service backup also applies the retention
policy and runs `restic check`. It reads a random 5% of stored pack data on each
run so payload damage is detected over time. A failed scheduled backup also
sends a critical desktop notification when Jason is logged in and writes to
logged-in terminals and the system journal.

## Final Backup Before Reinstalling

First commit and push the NixOS repository. Then close Codex and other
applications so their latest state is written to disk.

1. Log out of the graphical desktop from its system menu.
2. At the graphical login screen, press `Ctrl-Alt-F3`. If the function row is
   in media-key mode, press `Ctrl-Alt-Fn-F3`.
3. Log in as `jason`. The password remains invisible while typing.
4. Run:

   ```bash
   sudo systemctl start restic-backups-jason-home.service
   sudo restic-jason-home snapshots --host "$(hostname)" --latest 1
   ```

The first command waits for the backup and repository check to finish. Confirm
that the displayed snapshot has the current date and time. Record its snapshot
ID somewhere available during the replacement, then protect it from retention:

```bash
sudo restic-jason-home tag --add archive SNAPSHOT_ID
```

Do not erase the old disk yet. Keep it intact until the replacement laptop has
restored this exact snapshot and completed its first verified backup.

This TTY step improves consistency for open application databases. Normal daily
backups remain useful without it.

## Put a Replacement SSH Key on the NAS

Use this only when the old private key is unavailable. The private key stays on
the laptop; only the public `.pub` line goes to the NAS.

1. Create the key on NixOS:

   ```bash
   sudo install -d -m 700 -o root -g root /var/lib/secrets
   sudo ssh-keygen -t ed25519 -N "" \
     -C "restic-jason@$(hostname)" \
     -f /var/lib/secrets/restic-ssh-key
   sudo chmod 600 /var/lib/secrets/restic-ssh-key
   sudo cat /var/lib/secrets/restic-ssh-key.pub
   ```

2. Copy the complete single output line beginning with `ssh-ed25519`.
3. Sign in to Synology DSM as an administrator.
4. Open **Control Panel -> Task Scheduler**.
5. Choose **Create -> Scheduled Task -> User-defined script**.
6. Name it `Install Jason Restic key` and set the user to `root`.
7. Under **Task Settings**, paste the script below. Replace
   `PASTE_PUBLIC_KEY_HERE`, keeping the single quotes.

   ```sh
   set -eu

   user="restic-jason"
   home="/var/services/homes/$user"
   key='PASTE_PUBLIC_KEY_HERE'

   install -d -m 700 -o "$user" -g users "$home/.ssh"
   printf '%s\n' "$key" > "$home/.ssh/authorized_keys"
   chown "$user":users "$home/.ssh/authorized_keys"
   chmod 600 "$home/.ssh/authorized_keys"
   chmod go-w "$home"
   ```

8. Save the task, select it, and click **Run**. This replaces the old key for
   the dedicated `restic-jason` account.
9. On NixOS, test access:

   ```bash
   sudo restic-jason-home snapshots
   ```

10. After the snapshot list appears, delete the temporary DSM task.

The SSH key only opens the SFTP connection. The Restic password is still needed
to decrypt the repository.

## Replace the AMD Laptop with the Intel Laptop

The Intel profiles use the same encrypted repository and backup password. The
replacement workflow deliberately replaces the NAS SSH key, revoking the AMD
laptop before it is sold.

1. Commit and push this repository, then complete the
   [final logged-out backup](#final-backup-before-reinstalling) on the AMD
   laptop.
2. Install the Intel laptop using `framework-intel-core-ultra`, optionally with
   the `-gnome`, `-cinnamon`, `-cosmic`, or `-hyprland` suffix.
3. Follow the full recovery below. Generate a new Intel SSH key and use the DSM
   task to replace the old AMD key.
4. Restore the recorded AMD snapshot ID and verify important data. Do not use
   `latest` during the replacement.
5. Run a new backup from Intel and confirm its snapshot appears.
6. Only then erase the AMD laptop for sale.

## Restore the Entire Home on the Current Installation

This restores every file present in the chosen backup into the current home. It
is a merge: backed-up files overwrite matching files, but current files that are
absent from the snapshot are not deleted. Files excluded from backups are not
recreated. Commit or copy aside anything current that must not be overwritten.

1. Choose a snapshot ID with the [quick-reference commands](#choose-and-inspect-a-snapshot).
2. Close applications, log out, switch to a TTY with `Ctrl-Alt-F3` or
   `Ctrl-Alt-Fn-F3`, and log in as `jason`.
3. Stop new backup runs and the graphical login manager. If the backup service
   is already active, let it finish before continuing.

   ```bash
   sudo systemctl stop restic-backups-jason-home.timer
   systemctl status restic-backups-jason-home.service
   sudo systemctl stop display-manager.service
   ```

4. Restore the selected snapshot into the dedicated staging directory. Here,
   `--delete` cleans only that staging directory if it contains an older restore;
   it does not delete anything from the live home.

   ```bash
   sudo restic-jason-home restore SNAPSHOT_ID \
     --target /mnt/restic-restore \
     --delete --verify
   ```

5. Preview the merge, then apply it:

   ```bash
   sudo rsync -aHAXn --numeric-ids --itemize-changes \
     /mnt/restic-restore/home/jason/ /home/jason/
   sudo rsync -aHAX --numeric-ids \
     /mnt/restic-restore/home/jason/ /home/jason/
   sudo reboot
   ```

The configured timer starts again after the reboot. Verify important files
before removing `/mnt/restic-restore`.

## Full Recovery on a Fresh Installation

### 1. Install and rebuild NixOS

The example commands target the replacement Intel laptop with Plasma. Append
`-gnome`, `-cinnamon`, `-cosmic`, or `-hyprland` to `profile` to start
elsewhere. For the AMD laptop, set both variables to `framework-amd-ai-300`.
Desktop state from the backup remains available regardless of the starting
profile.

Install NixOS with the graphical installer:

```text
erase disk
no encryption
Plasma desktop
no swap
user: jason
```

After the first reboot, open a terminal and run:

```bash
mkdir -p ~/Documents/repos
cd ~/Documents/repos
nix-shell -p git
git clone https://github.com/jbrake/nixos-config.git
cd nixos-config
hardware=framework-intel-core-ultra
profile=framework-intel-core-ultra
cp /etc/nixos/hardware-configuration.nix \
  "hosts/$hardware/hardware-configuration.nix"
sudo NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild boot --flake ".#$profile"
sudo reboot
```

The generated hardware file must replace the repository copy because the new
filesystem has new identifiers.

### 2. Recreate the Restic password file

After rebooting into the rebuilt system, stop the timer before giving the new
laptop repository access. This prevents a fresh Intel-home snapshot from being
created before the AMD data is restored:

```bash
sudo systemctl stop restic-backups-jason-home.timer
sudo install -d -m 700 -o root -g root /var/lib/secrets
sudoedit /var/lib/secrets/restic-password
sudo chown root:root /var/lib/secrets/restic-password
sudo chmod 600 /var/lib/secrets/restic-password
```

Enter only the Restic password, save, and exit.

### 3. Restore NAS access

Follow [Put a Replacement SSH Key on the NAS](#put-a-replacement-ssh-key-on-the-nas).
If the old private key was deliberately saved elsewhere, it can instead be
restored to `/var/lib/secrets/restic-ssh-key` as `root:root` mode `0600`.

Confirm that both secrets work:

```bash
sudo restic-jason-home snapshots --host framework-amd-ai-300
```

Do not continue until the snapshots are listed. Identify the archived final AMD
snapshot recorded before the replacement and use that explicit ID below. Do not
use `latest`: after both laptops have written to this repository, it means the
newest matching snapshot regardless of which laptop contains the wanted data.

### 4. Restore the home directory from a TTY

1. Log out of the graphical desktop.
2. At the graphical login screen, press `Ctrl-Alt-F3` or
   `Ctrl-Alt-Fn-F3` and log in as `jason`.
3. Stop the graphical login manager:

   ```bash
   sudo systemctl stop display-manager.service
   ```

4. Restore the recorded AMD snapshot into the staging directory. `--delete`
   removes stale files only from a previous staged restore, and `--verify`
   rereads the restored data before the live home is changed:

   ```bash
   sudo restic-jason-home restore AMD_SNAPSHOT_ID \
     --target /mnt/restic-restore \
     --delete --verify
   ```

5. Copy the restored home into place:

   ```bash
   sudo rsync -aHAX --numeric-ids \
     --exclude='/Documents/repos/nixos-config/' \
     /mnt/restic-restore/home/jason/ /home/jason/
   ```

The copy is a merge, not an exact mirror: it does not delete fresh files that
are absent from the backup. The exclusion keeps the fresh Git clone used for
rebuilding. The backed-up repository remains in `/mnt/restic-restore` if
uncommitted work must be recovered manually.

### 5. Rebuild and verify

From the same TTY:

```bash
cd /home/jason/Documents/repos/nixos-config
profile=framework-intel-core-ultra
sudo nixos-rebuild switch --flake ".#$profile"
sudo reboot
```

Log in and check documents, Brave, the selected desktop, PrismLauncher worlds,
SSH keys, and other important data. Applications may require authentication
again. See [Switching Desktop Environments](desktop-switching.md) to change
desktops or perform a clean GNOME migration without restoring other desktop
settings.

After the restored data looks correct, make the first Intel backup, confirm its
host and current timestamp, and ensure the timer is running:

```bash
sudo systemctl start restic-backups-jason-home.service
sudo restic-jason-home snapshots --host "$(hostname)" --latest 1
sudo systemctl start restic-backups-jason-home.timer
```

Keep the old AMD laptop intact until these commands succeed.

Only after confirming the restore, remove the temporary copy:

```bash
sudo rm -rf /mnt/restic-restore
```

## Restore an Older Version of a File or Directory

Search for the file if its snapshot ID is not already known, then inspect the
chosen snapshot:

```bash
sudo restic-jason-home find --host framework-amd-ai-300 example.txt
sudo restic-jason-home ls SNAPSHOT_ID /home/jason/Documents --recursive
```

Follow [Restore one or several paths](#restore-one-or-several-paths) using that
explicit snapshot ID. The staged example file will be under:

```text
/tmp/restic-restore.RANDOM/home/jason/Documents/example.txt
```

## Important Behavior and Limits

- A suspended laptop does not wake for a backup. A missed run starts after the
  laptop resumes or boots.
- If the laptop is away from the NAS, the run fails. Start a manual backup after
  returning home.
- Restic prevents normal sleep while a backup is running, but shutdown, forced
  suspend, or network loss can interrupt it. Run it again if that happens.
- Backups are file-level snapshots, not a single atomic snapshot of every open
  application database. Log out for the cleanest planned final backup.
- The tested restore on 2026-07-10 successfully recovered the full home backup,
  including Brave, Plasma, PrismLauncher instances, and Minecraft worlds.
- The NAS is in the same physical location, so this is not yet a complete 3-2-1
  backup. An eventual off-site copy is still recommended.
