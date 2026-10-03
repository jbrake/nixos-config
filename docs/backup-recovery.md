# Restic Backup and Recovery

Jason's home directory is backed up daily to an encrypted Restic repository on
an external USB disk (Samsung 850 PRO, ext4, label `Backup`). NixOS configures
the job and the disk mount; one root-only secret, the repository password,
provides access.

The Synology NAS target is retained in `modules/nixos/backup.nix`, commented
out. See [Switching Back to the NAS](#switching-back-to-the-nas). Snapshots taken
before the switch remain in the NAS repository; the disk repository starts
fresh.

## Reinstalling? Start Here

1. If the old system still works, take a
   [final backup](#final-backup-before-reinstalling) first.
2. Follow [Full Recovery on a Fresh Installation](#full-recovery-on-a-fresh-installation)
   from top to bottom. In short: install NixOS, clone this repo, rebuild, add
   the Restic password, plug in the disk, restore, rebuild again.

Read this page on a phone or another computer while recovering:
<https://github.com/jbrake/nixos-config/blob/main/docs/backup-recovery.md>

### Be ready before you need it

- The Restic password is saved somewhere reachable **without this laptop**, such
  as a phone password manager or on paper. A password manager whose only copy
  is in the backed-up home directory does not count.
- The backup disk has a recent snapshot: `sudo restic-jason-home snapshots`.

## Quick Reference

These commands assume the configured NixOS system, the
[required secret](#required-secret), and a plugged-in backup disk. Always choose an explicit
snapshot ID before restoring. This prevents a fresh installation's empty home
snapshot or another historical snapshot from being selected accidentally.

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
sudo restic-jason-home find --host framework-intel-core-ultra example.txt
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
after reinstalling or replacing a disk. Both workflows restore into a staging
directory first and preserve the active Git checkout. Do not point Restic
directly at `/home/jason`.

## Configuration

```text
source:      /home/jason
repository:  /mnt/backup/restic-jason
disk:        /dev/disk/by-uuid/c93b20f8-c021-48b7-8942-da505215827f
checkout:    /home/jason/Documents/repos/nixos-config
schedule:    daily, with missed runs started after boot or resume
retention:   7 daily, 5 weekly, 12 monthly, 3 yearly
protected:   snapshots tagged archive
```

The backup includes documents, all five desktop state capsules, Brave Origin
profiles and extensions, PrismLauncher instances and Minecraft worlds, Codex
sessions, SSH keys, desktop credential stores, and other files under
`/home/jason`.

Desktop capsules and Restic serve different purposes. Capsules automatically
preserve each desktop's latest local state during switching; Restic keeps
historical home snapshots on the backup disk for reinstallations and disaster
recovery.
See [Switching Desktop Environments](desktop-switching.md) for the short workflow.

It excludes:

```text
~/.cache
~/.local/share/Trash
~/.local/state/home-manager
~/.local/state/nix
~/Downloads
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

## Backup Disk

The disk is automounted at `/mnt/backup` on first access and unmounted after
five idle minutes, so it is safe to unplug between backups. It never mounts at
boot, and a missing disk does not delay booting.

The automount is deliberate. When the disk is unplugged, a backup fails against
the empty autofs mount point instead of initializing a new repository on the
laptop's own disk. Check that the disk is visible with:

```bash
ls /mnt/backup
```

The top of the disk is owned by `jason`, so other files can be copied there
normally. Only `restic-jason/` is root-only: it is Restic's encrypted
repository, not browsable files. Never edit or delete anything inside it by
hand. To browse backed-up files, mount the snapshots instead:

```bash
mkdir -p ~/backup-browse
sudo restic-jason-home mount ~/backup-browse
```

A reformatted or replacement disk needs its new UUID in
`modules/nixos/backup.nix` and a one-time `sudo chown jason:users /mnt/backup`.

## Required Secret

```text
/var/lib/secrets/restic-password   decrypts the Restic repository
```

Restic always encrypts its repository, so this password is required. It matters
more for a portable disk than for the NAS: anyone holding the disk still needs
it to read the backup. The password is irreplaceable. Keep it somewhere outside
the laptop and the backup disk.

`/var/lib/secrets/restic-ssh-key` is only used by the NAS target. It is unused
while backing up to the disk, but keep it if switching back is likely.

Neither secret belongs in Git. The NixOS config, NAS address, account name,
disk UUID, and public SSH keys are safe in a public repository.

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
logged-in terminals and the system journal. A successful run sends a normal
desktop notification after the backup, retention, and repository check phases
all complete.

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
ID somewhere available during recovery, then protect it from retention:

```bash
sudo restic-jason-home tag --add archive SNAPSHOT_ID
```

Before reformatting, do not erase the disk until this exact snapshot is visible
and protected in the Restic repository. When replacing a disk, keep the old disk
intact until the new installation has restored the snapshot and completed its
first verified backup.

This TTY step improves consistency for open application databases. Normal daily
backups remain useful without it.

## Switching Back to the NAS

In `modules/nixos/backup.nix`, uncomment the `programs.ssh.knownHosts` block,
the `sftp:` repository line, and `extraOptions`, then delete the
`${diskMount}` repository line. The `fileSystems` mount can stay. Rebuild, then
confirm access:

```bash
sudo restic-jason-home snapshots
```

The SSH key must exist at `/var/lib/secrets/restic-ssh-key`; if it does not,
follow the next section.

## Put a Replacement SSH Key on the NAS

Only needed for the NAS target, and only when the old private key is
unavailable. The private key stays on
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
     --exclude='/Documents/repos/nixos-config/' \
     /mnt/restic-restore/home/jason/ /home/jason/
   sudo rsync -aHAX --numeric-ids \
     --exclude='/Documents/repos/nixos-config/' \
     /mnt/restic-restore/home/jason/ /home/jason/
   sudo reboot
   ```

The repository exclusion prevents an older backed-up checkout from replacing
the current Git-managed configuration. Its staged copy remains available under
`/mnt/restic-restore` if uncommitted files need to be recovered manually. The
configured timer starts again after the reboot. Verify important files before
removing `/mnt/restic-restore`.

## Full Recovery on a Fresh Installation

You need:

- the same laptop model (the commands use `framework-intel-core-ultra`)
- the USB backup disk, **left unplugged until step 3**
- the Restic password
- an internet connection

Steps 4 and 5 run in a text console where copy and paste do not work, so their
commands are short enough to type.

### 1. Install NixOS and apply this configuration

Keep the backup disk unplugged. Install NixOS with the graphical installer:

```text
erase disk
no encryption
Plasma desktop
no swap
user: jason
```

After the first reboot, log in, open a terminal, and run:

```bash
mkdir -p ~/Documents/repos
cd ~/Documents/repos
nix-shell -p git --run "git clone https://github.com/jbrake/nixos-config.git"
cd nixos-config
cp /etc/nixos/hardware-configuration.nix \
  hosts/framework-intel-core-ultra/hardware-configuration.nix
sudo NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild boot --flake .#framework-intel-core-ultra
sudo reboot
```

The `cp` line is required: a freshly formatted disk has new identifiers, and the
old hardware file would not boot. The rebuild downloads and builds a lot and can
take a while. To start in another desktop, append `-gnome`, `-cinnamon`,
`-cosmic`, or `-hyprland` to the name after `#`; restored desktop state works
with any of them.

### 2. Stop automatic backups and add the password

Log in again and open a terminal. First stop the backup timer **and** any
pending retry, so the new, nearly empty home is never backed up over the real
one:

```bash
sudo systemctl stop restic-backups-jason-home.timer restic-backups-jason-home.service
```

Then create the password file. An editor opens: type only the Restic password,
save, and exit (in nano: `Ctrl-O`, `Enter`, `Ctrl-X`).

```bash
sudo install -d -m 700 -o root -g root /var/lib/secrets
sudoedit /var/lib/secrets/restic-password
sudo chmod 600 /var/lib/secrets/restic-password
```

### 3. Plug in the disk and choose a snapshot

Plug in the backup disk, then list the snapshots:

```bash
sudo restic-jason-home snapshots --host framework-intel-core-ultra
```

If this shows a password error, redo the `sudoedit` line from step 2. If it
cannot find the repository, check that the disk is plugged in with
`ls /mnt/backup`.

Pick the snapshot to restore:

- After a planned reinstall: the ID recorded during the
  [final backup](#final-backup-before-reinstalling). It is tagged `archive`.
- Otherwise: the newest snapshot dated **before** the reinstall.

The ID is the 8-character value in the first column. Protect it so the
retention policy can never remove it, even if something goes wrong later:

```bash
sudo restic-jason-home tag --add archive SNAPSHOT_ID
```

Write the ID down; step 4 needs it typed by hand. Never use `latest` here.

### 4. Restore the home directory from a text console

1. Log out of the desktop.
2. At the login screen, press `Ctrl-Alt-F3` (or `Ctrl-Alt-Fn-F3`) and log in as
   `jason`. The password is invisible while typing.
3. Stop the graphical login screen so nothing writes to the home directory:

   ```bash
   sudo systemctl stop display-manager.service
   ```

4. Restore the snapshot into a staging folder. Replace `SNAPSHOT_ID` with the
   ID from step 3. This changes nothing in the home directory yet:

   ```bash
   sudo restic-jason-home restore SNAPSHOT_ID --target /mnt/restic-restore --delete --verify
   ```

   It needs free space on the laptop about the size of the backed-up home and
   can take a long time. Wait for the prompt to return without errors.

5. Copy the restored files into the home directory:

   ```bash
   sudo rsync -aHAX --numeric-ids --exclude=/Documents/repos/nixos-config/ /mnt/restic-restore/home/jason/ /home/jason/
   ```

   Type both trailing slashes exactly. The exclusion keeps the fresh repository
   clone from step 1; the backed-up copy stays in `/mnt/restic-restore` in case
   it held uncommitted work. The copy only adds and overwrites files; it never
   deletes anything.

### 5. Rebuild, reboot, and check

Still in the text console:

```bash
cd ~/Documents/repos/nixos-config
sudo nixos-rebuild switch --flake .#framework-intel-core-ultra
sudo reboot
```

Log in and check documents, Brave Origin, the desktop, PrismLauncher worlds,
SSH keys, and anything else important. Some applications ask you to sign in
again. See [Switching Desktop Environments](desktop-switching.md) to change
desktops or perform a clean GNOME migration.

### 6. Finish up

Commit the new hardware file so the next clone matches this installation. The
restored SSH key is used for the push:

```bash
cd ~/Documents/repos/nixos-config
git remote set-url origin git@github.com:jbrake/nixos-config.git
git add hosts/framework-intel-core-ultra/hardware-configuration.nix
git commit -m "update hardware configuration after reinstall"
git push
```

Make the first backup of the restored system and confirm it has today's date.
The reboot in step 5 already turned the daily timer back on:

```bash
sudo systemctl start restic-backups-jason-home.service
sudo restic-jason-home snapshots --host "$(hostname)" --latest 1
```

Once everything looks right, delete the staging copy:

```bash
sudo rm -rf /mnt/restic-restore
```

## Restore an Older Version of a File or Directory

Search for the file if its snapshot ID is not already known, then inspect the
chosen snapshot:

```bash
sudo restic-jason-home find --host framework-intel-core-ultra example.txt
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
- If the backup disk is not plugged in, a failed run retries every 10 minutes
  for roughly two hours. Intermediate failures do not send desktop
  notifications. If all retries are exhausted, plug in the disk and start a
  manual backup.
- Restic prevents normal sleep while a backup is running, but shutdown, forced
  suspend, or unplugging the disk can interrupt it. Run it again if that happens.
- Backups are file-level snapshots, not a single atomic snapshot of every open
  application database. Log out for the cleanest planned final backup.
- The tested restore on 2026-07-10 successfully recovered the full home backup,
  including Brave Origin, Plasma, PrismLauncher instances, and Minecraft worlds.
- The backup disk is a single copy, usually kept near the laptop, so this is
  not a complete 3-2-1 backup. The older NAS repository is a second copy only
  up to the switch date. An off-site copy is still recommended.
