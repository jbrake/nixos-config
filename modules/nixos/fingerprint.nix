{ lib, pkgs, ... }:

let
  fingerprintWake = pkgs.writeShellApplication {
    name = "framework-fingerprint-wake";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
    ];
    text = ''
      vendor_id=27c6
      product_id=609c
      state_dir="''${RUNTIME_DIRECTORY:-/run/framework-fingerprint-wake}"
      controller_file="$state_dir/controller"

      find_reader() {
        local device found_vendor found_product

        for device in /sys/bus/usb/devices/*; do
          [[ -r "$device/idVendor" && -r "$device/idProduct" ]] || continue
          read -r found_vendor < "$device/idVendor"
          read -r found_product < "$device/idProduct"
          if [[ "$found_vendor" == "$vendor_id" && "$found_product" == "$product_id" ]]; then
            printf '%s\n' "$device"
            return 0
          fi
        done
        return 1
      }

      remember_controller() {
        local device="$1" path driver controller

        path="$(${lib.getExe' pkgs.coreutils "readlink"} -f "$device")"
        while [[ "$path" == /sys/devices/* ]]; do
          if [[ -L "$path/driver" ]]; then
            driver="$(${lib.getExe' pkgs.coreutils "basename"} "$(${lib.getExe' pkgs.coreutils "readlink"} -f "$path/driver")")"
            controller="$(${lib.getExe' pkgs.coreutils "basename"} "$path")"
            if [[ "$driver" == xhci* && "$controller" =~ ^0000:[[:xdigit:]]{2}:[[:xdigit:]]{2}\.[0-7]$ ]]; then
              printf '%s\n' "$controller" > "$controller_file"
              return 0
            fi
          fi
          path="''${path%/*}"
        done

        echo "Could not resolve the fingerprint reader's xHCI controller" >&2
        return 1
      }

      record_reader() {
        local device

        if ! device="$(find_reader)"; then
          echo "Goodix fingerprint reader is not present; controller was not recorded" >&2
          return 1
        fi
        remember_controller "$device"
        echo "Recorded fingerprint controller $(<"$controller_file")"
      }

      recover_reader() {
        local device controller pci_device driver driver_dir

        echo "Checking fingerprint reader after wake"
        sleep 2

        if device="$(find_reader)"; then
          remember_controller "$device"
          echo "Fingerprint reader is present; no recovery needed"
          return 0
        fi

        if [[ ! -r "$controller_file" ]]; then
          echo "Fingerprint reader is missing and no saved controller is available" >&2
          return 1
        fi
        read -r controller < "$controller_file"
        if [[ ! "$controller" =~ ^0000:[[:xdigit:]]{2}:[[:xdigit:]]{2}\.[0-7]$ ]]; then
          echo "Refusing invalid saved PCI controller: $controller" >&2
          return 1
        fi

        pci_device="/sys/bus/pci/devices/$controller"
        if [[ ! -L "$pci_device/driver" ]]; then
          echo "Fingerprint controller $controller has no bound driver" >&2
          return 1
        fi
        driver="$(${lib.getExe' pkgs.coreutils "basename"} "$(${lib.getExe' pkgs.coreutils "readlink"} -f "$pci_device/driver")")"
        if [[ "$driver" != xhci* ]]; then
          echo "Refusing to reset non-xHCI driver $driver for $controller" >&2
          return 1
        fi
        driver_dir="/sys/bus/pci/drivers/$driver"

        echo "Fingerprint reader is missing; resetting controller $controller"
        systemctl stop fprintd.service || true
        printf '%s\n' "$controller" > "$driver_dir/unbind"
        sleep 1
        printf '%s\n' "$controller" > "$driver_dir/bind"
        sleep 2

        if device="$(find_reader)"; then
          remember_controller "$device"
          systemctl try-restart fprintd.service
          echo "Fingerprint reader restored"
        else
          echo "Fingerprint reader is still missing after resetting $controller" >&2
          return 1
        fi
      }

      mkdir -p "$state_dir"
      case "''${1:-}" in
        record) record_reader ;;
        recover) recover_reader ;;
        *) echo "usage: framework-fingerprint-wake {record|recover}" >&2; exit 2 ;;
      esac
    '';
  };

  sleepTargets = [
    "suspend.target"
    "hibernate.target"
    "hybrid-sleep.target"
    "suspend-then-hibernate.target"
  ];
in
{
  services.fprintd.enable = true;

  # Framework's Goodix reader can be flaky after suspend when it is left in
  # runtime autosuspend. Keep only this internal fingerprint device awake.
  services.udev.extraRules = lib.mkAfter ''
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="27c6", ATTR{idProduct}=="609c", TEST=="power/control", ATTR{power/control}="on"
  '';

  # If the lock screen is verifying while sleep begins, fprintd can keep the
  # reader busy and fail after resume. Stop it before sleep; D-Bus starts it
  # again on the next fingerprint request.
  powerManagement.powerDownCommands = lib.mkAfter ''
    ${pkgs.systemd}/bin/systemctl stop fprintd.service || true
  '';

  # Framework's recovery checks for this reader after every wake and only
  # resets its xHCI controller when the device failed to return. Discover the
  # controller at boot so recovery still knows the safe target while the USB
  # child device is missing. This is the declarative equivalent of Framework's
  # Fingerprint-Wake-Workaround installer.
  systemd.services.framework-fingerprint-controller = {
    description = "Remember the Framework fingerprint reader USB controller";
    wantedBy = [ "multi-user.target" ];
    before = sleepTargets;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "framework-fingerprint-wake";
      ExecStart = "${fingerprintWake}/bin/framework-fingerprint-wake record";
    };
  };

  systemd.services.framework-fingerprint-wake = {
    description = "Restore the Framework fingerprint reader after resume";
    wantedBy = sleepTargets;
    wants = [ "framework-fingerprint-controller.service" ];
    after = sleepTargets ++ [ "framework-fingerprint-controller.service" ];
    serviceConfig = {
      Type = "oneshot";
      RuntimeDirectory = "framework-fingerprint-wake";
      RuntimeDirectoryPreserve = true;
      ExecStart = "${fingerprintWake}/bin/framework-fingerprint-wake recover";
    };
  };

  # Fingerprint auth is deliberately SUDO-ONLY. This mirrors the setup that
  # took real effort to get right on CachyOS (2026-04): PAM modules run
  # sequentially, so pam_fprintd in an interactive login stack makes the
  # password prompt block for 30+ seconds while fprintd waits for a scan.
  #
  # NixOS defaults <service>.fprintAuth = services.fprintd.enable for EVERY
  # PAM service, so everything except sudo must be switched off explicitly.
  #
  # The Plasma lock screen does NOT need pam_fprintd: kscreenlocker talks to
  # fprintd natively over D-Bus (via the separate "kde-fingerprint" PAM
  # service, which nixpkgs manages) in parallel with the password prompt.
  # Leave "kde" and "kde-fingerprint" alone — upstream configures them.
  security.pam.services = {
    # sudo: fprintAuth left at its default (true). NixOS generates
    # "auth sufficient pam_fprintd.so" ahead of pam_unix — scan to auth,
    # or just type the password; either works. Blocking is fine in a
    # terminal that is waiting for input anyway.
    login.fprintAuth = false;
    su.fprintAuth = false;
    sddm.fprintAuth = false;
    sddm-greeter.fprintAuth = false;
    hyprlock.fprintAuth = false;
    # Keeps GUI polkit dialogs from blocking on a scan (nixpkgs #171136).
    "polkit-1".fprintAuth = false;
  };
}
