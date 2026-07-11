# Restic Backup and Full-System Recovery

Jason's home directory is backed up with Restic to an encrypted repository on
the local Synology NAS. NixOS declares the client, schedule, retention policy,
exclusions, NAS identity, and repository location in
`modules/nixos/backup.nix`. The repository password and client SSH private key
never enter Git or the Nix store.

## Current Setup

```text
job:         jason-home
source:      /home/jason
repository:  sftp:restic-jason@10.69.1.164:/restic-jason
schedule:    daily, persistent, with up to one hour randomized delay
retention:   7 daily, 5 weekly, 12 monthly, 3 yearly
```

The timer runs missed backups after the laptop wakes. While a backup, prune, or
repository check is active, the service requests a blocking system sleep
inhibitor.

The following reproducible or disposable paths are excluded:

```text
~/.cache
~/.local/share/Trash
~/.local/state/home-manager
~/.local/state/nix
~/.local/share/Steam/steamapps/common
~/.local/share/Steam/steamapps/downloading
~/.local/share/Steam/steamapps/shadercache
~/.local/share/Steam/steamapps/temp
~/.local/share/Steam/steamapps/workshop
directories marked with CACHEDIR.TAG
```

Everything else under `/home/jason` is included, including documents, browser
profiles, Plasma state, SSH keys, application settings, retained Steam state,
and PrismLauncher data.

## What Is and Is Not Backed Up

### Plasma, Browsers, Documents, and Other Home Data

The job backs up the whole `/home/jason` tree except for the exclusions above.
That includes unmanaged Plasma configuration, Brave's profile and extensions,
documents, downloads, projects, SSH keys, KDE Wallet data, Telegram data, and
other application state stored in the home directory.

Applications may still require a new login after recovery. Browser cookies,
tokens, and saved credentials can expire or depend on keyring state even when
their files restore correctly. For the cleanest planned migration, log out of
Plasma and run a final manual backup from a TTY so applications are not changing
their databases during the snapshot.

### PrismLauncher and Minecraft Worlds

PrismLauncher's complete data tree is currently under:

```text
/home/jason/.local/share/PrismLauncher
```

It is included. This covers launcher configuration, instances, mods, resource
packs, and Minecraft worlds under each instance's `minecraft/saves` directory.
The tree is not marked with `CACHEDIR.TAG`, so `--exclude-caches` does not omit
it. Microsoft or third-party accounts may still require authentication after a
restore.

### Steam

Downloaded games and other re-downloadable Steam content are excluded. The
largest excluded directory is currently `steamapps/common` at about 11 GiB.
Downloads in progress, shader caches, temporary files, and Workshop downloads
are also omitted.

The backup keeps `userdata`, Steam configuration, screenshots, library
metadata, and `steamapps/compatdata`. Proton prefixes are retained because some
games store non-cloud saves or configuration inside them. Steam may need to
redownload games and Workshop items after a full restore, which is intentional.

### QEMU and virt-manager VMs

System libvirt VM disks are not currently backed up. The two present disks are
outside the home backup:

```text
/var/lib/libvirt/images/nixos-cinnamon.qcow2
/var/lib/libvirt/images/nixos-unstable.qcow2
```

The NixOS VM targets in this repository can help recreate guest operating
systems, but they do not contain the guest disks or system libvirt domain XML.
Any disposable test VMs can therefore be rebuilt, while unique data inside them
would be lost with the host disk.

Do not add `/var/lib/libvirt/images` blindly to the home job. Copying a qcow2
disk while its VM is writing can produce a crash-consistent or unusable backup.
Important VMs should use a separate root-run Restic job that captures both disk
images and exported domain XML only while the guests are shut down, or a proper
libvirt backup/snapshot workflow.

## Suspend and Lid Behavior

The timer uses a realtime daily calendar event, `Persistent=true`, and up to one
hour of randomized delay.

- If the laptop is already suspended when the event elapses, it does not wake
  solely for the backup because `WakeSystem` is not enabled.
- On resume, systemd catches up and starts one backup for the missed event.
  Multiple events missed during one continuous sleep result in one activation.
- A backup missed while the machine was powered off is also caught after the
  timer becomes active again, subject to the randomized delay.
- If the laptop resumes away from the home NAS, that attempt fails and the
  current configuration waits until the next daily event. Run the service
  manually after returning home if an immediate backup matters.
- Once Restic is running, the service holds a blocking `sleep` inhibitor.
  Plasma PowerDevil currently owns the lid switch and should honor that request
  during normal suspend handling. Forced suspend, shutdown, loss of network, or
  firmware behavior can still interrupt a run; check the service journal if
  that happens and start it again manually.

`WakeSystem=true` is intentionally not used: waking a closed laptop in a bag to
reach a LAN-only NAS is undesirable and may occur when the NAS is unreachable.

## Public Repository Safety

This module and this recovery document are safe to publish. They expose only:

- a private-LAN IP address;
- the NAS service account and shared-folder names;
- the public NAS SSH host key;
- local usernames, paths, schedule, exclusions, and retention policy.

Those values cannot authenticate to the NAS or decrypt a copied Restic
repository. The client SSH private key and Restic password remain root-only
files under `/var/lib/secrets` and must never be added to Git or the Nix store.
The SSH public key is not a secret, but the corresponding private key is.

Publishing recovery steps does not weaken the design: security depends on the
SSH private key, repository password, NAS permissions, and network access—not
on hiding the procedure.

## Recovery Secrets

The live machine expects:

```text
/var/lib/secrets/restic-password
/var/lib/secrets/restic-ssh-key
```

Both files must be owned by `root:root` with mode `0600`. The directory must be
owned by root with mode `0700`.

The Restic password is the irreplaceable recovery secret. Keep it in a
cross-device password manager and an offline recovery location. The SSH key is
replaceable: generate a new key and authorize its public half for the
`restic-jason` Synology account if the laptop is lost.

Never commit either secret. The NAS SSH host key in `backup.nix` is public and
belongs in Git.

### Authorizing a Replacement SSH Key

The new private key stays on the laptop. Only its public half is copied to the
NAS. The public key lets the NAS recognize this Restic client; it cannot decrypt
the backup. The separate Restic repository password is still required for that.

First, display the replacement public key:

```bash
sudo cat /var/lib/secrets/restic-ssh-key.pub
```

Copy the entire single line beginning with `ssh-ed25519`. It is safe to move
this public line through the clipboard, email, or another computer; do not copy
or expose the private file with the same name but no `.pub` suffix.

Then authorize it from the Synology web interface:

1. Sign in to DSM as an administrator. From the home network, use the normal
   bookmarked DSM address or `https://10.69.1.164:5001` if the default HTTPS
   port has not been changed.
2. Open **Control Panel -> Task Scheduler**.
3. Choose **Create -> Scheduled Task -> User-defined script**.
4. On **General**, give it a temporary name such as `Install Jason Restic key`
   and select `root` as the task user. The task must run as root because DSM
   does not provide an ordinary editor for another user's `authorized_keys`.
5. On **Task Settings**, paste the script below into **User-defined script**.
   Replace `PASTE_PUBLIC_KEY_HERE` with the complete public-key line copied in
   the previous step. Keep the single quotes around it.
6. Save the task, select it in Task Scheduler, choose **Run**, and confirm. DSM
   may ask for the administrator password again. Wait for the task status to
   show that it completed.

The script preserves an existing authorized key and adds the new one only if it
is not already present:

```sh
set -eu

user="restic-jason"
home="/var/services/homes/$user"
key='PASTE_PUBLIC_KEY_HERE'

install -d -m 700 -o "$user" -g users "$home/.ssh"
touch "$home/.ssh/authorized_keys"
if ! grep -qxF "$key" "$home/.ssh/authorized_keys"; then
  printf '%s\n' "$key" >> "$home/.ssh/authorized_keys"
fi
chown "$user":users "$home/.ssh/authorized_keys"
chmod 600 "$home/.ssh/authorized_keys"
chmod go-w "$home"
```

Back on the NixOS machine, prove that the new SSH key reaches the repository and
that the Restic password decrypts it:

```bash
sudo restic-jason-home snapshots
```

Only a snapshot listing is performed; this does not create, remove, or alter a
backup. After it succeeds, delete the temporary DSM task so it cannot be run
again accidentally. If the old private key may have been stolen, also remove
its corresponding public-key line from `authorized_keys`; merely losing an old
private key does not require immediate removal, but leaving unused access in
place is unnecessary.

## Routine Commands

Show the next scheduled run:

```bash
systemctl list-timers restic-backups-jason-home.timer --all
```

Start a backup immediately:

```bash
sudo systemctl start restic-backups-jason-home.service
```

`systemctl start` waits until backup, retention, and checking finish. It is
quiet while running because Restic writes to the system journal. To launch it
in the background instead:

```bash
sudo systemctl start --no-block restic-backups-jason-home.service
journalctl -fu restic-backups-jason-home.service
```

Stop following the journal with `Ctrl-C` after it reports that the service
finished. The backup itself continues independently of the journal command.

Inspect recent service output:

```bash
journalctl -u restic-backups-jason-home.service --since yesterday
```

The NixOS module provides a wrapper with the repository and password-file
environment already set:

```bash
sudo restic-jason-home snapshots
sudo restic-jason-home stats latest
sudo restic-jason-home check
```

### GUI Options and Monitoring

Restic itself is intentionally a command-line tool. The backup is not based on
blind trust: every scheduled run creates an immutable snapshot, applies the
retention policy, and runs `restic check`. The initial repository also passed a
real byte-for-byte restore test. Use `snapshots`, `stats`, the systemd service
status, and its journal to inspect operation at any time.

[Backrest](https://github.com/garethgeorge/backrest) is an actively maintained
web UI and Restic orchestrator. It would overlap with the NixOS systemd job and
create a second scheduler, so it is not installed here. [Restic
Browser](https://github.com/emuell/restic-browser) focuses on browsing and
restoring existing repositories, but a desktop GUI would need access to the
root-only repository password and SSH private key. Keeping those credentials
away from the graphical user session is the safer default.

For occasional graphical browsing without giving a GUI permanent credentials,
Restic can instead mount a repository temporarily as a filesystem from a
root-run terminal. Add that workflow only if it becomes useful; normal backup
operation does not require it.

## Selective Restore

Restore into a staging directory first instead of overwriting a live file:

```bash
sudo restic-jason-home restore latest \
  --target /tmp/restic-restore \
  --include /home/jason/Documents/example.txt
```

The restored path will be:

```text
/tmp/restic-restore/home/jason/Documents/example.txt
```

Inspect or copy the file, then remove the staging directory:

```bash
sudo rm -rf /tmp/restic-restore
```

## Working From a TTY

A TTY is a full-screen text login provided directly by Linux. It does not
depend on Plasma, and it remains available even when the graphical login screen
is stopped. This makes it the safest place to restore a home directory because
Brave, Plasma, and other desktop applications cannot modify the same files
while they are being copied.

For a planned final backup or recovery:

1. Save work and close applications. In Plasma, open the application launcher,
   choose **Leave**, and select **Log Out**. Wait for the graphical login screen.
2. Press `Ctrl-Alt-F3` to open a text console. On a keyboard where the function
   row is in media-key mode, use `Ctrl-Alt-Fn-F3`. TTYs are normally available
   on `F2` through `F6`, so another one can be used if `F3` is occupied.
3. At `login:`, enter `jason`, press Enter, and enter the normal login password.
   Nothing is displayed while the password is typed; that is expected.
4. For a full restore, prevent the graphical login manager from being started
   or used while files are copied:

   ```bash
   sudo systemctl stop display-manager.service
   ```

5. Run the restore, `rsync`, and rebuild commands from the recovery procedure
   below. Keeping this README open on a phone or another computer is useful
   because the TTY has no browser or graphical clipboard.
6. When recovery and the final rebuild are complete, either reboot or restart
   the graphical login screen:

   ```bash
   sudo systemctl start display-manager.service
   ```

   If it starts on a different virtual terminal, `Ctrl-Alt-F1` or
   `Ctrl-Alt-F2` normally returns to it.

For a final pre-wipe backup, logging out and switching to a TTY is enough; the
display manager does not need to be stopped. Run the usual manual backup there
and wait for it to finish:

```bash
sudo systemctl start restic-backups-jason-home.service
sudo restic-jason-home snapshots --latest 1
```

## Full Fresh-System Recovery

1. Install NixOS, clone this repository, and provide the generated hardware
   configuration as described in the main README.

2. Rebuild the correct host. This installs the Restic wrapper and declares the
   NAS connection even if the secret files do not exist yet.

   ```bash
   ./scripts/rebuild.sh framework-amd-ai-300
   ```

3. Recreate the secret directory and Restic password from the password manager.

   ```bash
   sudo install -d -m 700 -o root -g root /var/lib/secrets
   sudoedit /var/lib/secrets/restic-password
   sudo chown root:root /var/lib/secrets/restic-password
   sudo chmod 600 /var/lib/secrets/restic-password
   ```

4. Restore the old SSH private key from a separate safe copy, or create a
   replacement. Generating the key creates two files: the root-only private key
   at `/var/lib/secrets/restic-ssh-key` and the safe-to-copy public key at
   `/var/lib/secrets/restic-ssh-key.pub`.

   ```bash
   sudo ssh-keygen -t ed25519 -N "" \
     -C "restic-jason@framework-amd-ai-300" \
     -f /var/lib/secrets/restic-ssh-key
   sudo chmod 600 /var/lib/secrets/restic-ssh-key
   ```

   A newly generated key has no NAS access yet. Follow
   [Authorizing a Replacement SSH Key](#authorizing-a-replacement-ssh-key) to
   place only its public half in the `restic-jason` account's
   `authorized_keys` file on the Synology.

5. Prove that both authentication layers work.

   ```bash
   sudo restic-jason-home snapshots
   ```

6. Follow [Working From a TTY](#working-from-a-tty), including stopping the
   display manager, so browsers, Plasma, and other applications are not
   modifying their databases. Restore the latest snapshot into staging storage
   with enough free space.

   ```bash
   sudo restic-jason-home restore latest --target /mnt/restic-restore
   ```

7. Copy the restored home into place while preserving metadata.

   ```bash
   sudo rsync -aHAX --numeric-ids \
     --exclude='/Documents/repos/nixos-config/' \
     /mnt/restic-restore/home/jason/ /home/jason/
   ```

   The exclusion preserves the clean repository clone used for the new NixOS
   installation instead of overlaying it with the version captured in the
   backup. The backed-up copy remains available under
   `/mnt/restic-restore/home/jason/Documents/repos/nixos-config` if uncommitted
   work ever needs to be recovered manually.

8. Rebuild once more. Home Manager will reassert the files and symlinks it owns
   while leaving restored application data and unmanaged Plasma state intact.

   ```bash
   ./scripts/rebuild.sh framework-amd-ai-300
   ```

9. Log in, verify important applications and documents, and only then delete
   the staging restore.

## Periodic Restore Test

At least occasionally, restore a known small file into `/tmp`, compare it with
the live copy using `sha256sum` or `cmp`, and delete the staging tree. A backup
is not considered proven until a restore succeeds.

The initial verified snapshot on 2026-07-10 processed 147,781 files and 33.076
GiB, stored 20.060 GiB, and passed `restic check` plus a byte-for-byte README
restore test.

## Scope and Remaining Risk

This protects against laptop loss, drive failure, accidental deletion, and a
bad reinstall. The NAS remains in the same physical location, so this is not
yet a complete 3-2-1 backup. Synology snapshots protect the live repository
from accidental or credential-driven deletion; a later off-site copy protects
against theft, fire, and total NAS loss.
