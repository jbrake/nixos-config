{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.jbrake.frameworkFingerprint;

  fingerprintWake = pkgs.writeShellApplication {
    name = "framework-fingerprint-wake";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      vendor_id=27c6
      product_id=609c
      reset_mode=${lib.escapeShellArg cfg.resetMode}
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

      wait_for_reader() {
        local device attempt

        for (( attempt = 0; attempt < 20; attempt++ )); do
          if device="$(find_reader)"; then
            printf '%s\n' "$device"
            return 0
          fi
          sleep 0.25
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

      reset_controller() {
        local reason="$1"
        local device controller pci_device driver driver_dir

        if [[ ! -r "$controller_file" ]]; then
          echo "No saved fingerprint controller is available" >&2
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

        echo "Resetting fingerprint controller $controller $reason"
        printf '%s\n' "$controller" > "$driver_dir/unbind"
        sleep 1
        printf '%s\n' "$controller" > "$driver_dir/bind"

        if device="$(wait_for_reader)"; then
          remember_controller "$device"
          echo "Fingerprint reader restored"
        else
          echo "Fingerprint reader is still missing after resetting $controller" >&2
          return 1
        fi
      }

      recover_reader() {
        local device

        echo "Checking fingerprint reader after wake"
        sleep 2

        if [[ "$reset_mode" == "when-missing" ]] && device="$(find_reader)"; then
          remember_controller "$device"
          echo "Fingerprint reader is present; no recovery needed"
          return 0
        fi

        reset_controller "after wake"
      }

      prepare_reader() {
        reset_controller "before fprintd starts"
      }

      mkdir -p "$state_dir"
      case "''${1:-}" in
        record) record_reader ;;
        recover) recover_reader ;;
        prepare) prepare_reader ;;
        *) echo "usage: framework-fingerprint-wake {record|recover|prepare}" >&2; exit 2 ;;
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
  options.jbrake.frameworkFingerprint = {
    resetMode = lib.mkOption {
      type = lib.types.enum [
        "disabled"
        "when-missing"
        "always"
        "before-use"
      ];
      default = "disabled";
      description = "Controller recovery policy. Enable only after checking the host's USB topology.";
    };
    keepAwake = lib.mkEnableOption "disable runtime autosuspend for the Goodix reader";
    stopBeforeSleep = lib.mkEnableOption "stop fprintd before sleep outside Plasma";
  };

  config = {
    services.fprintd.enable = true;

    # Framework's Goodix reader can be flaky after suspend when it is left in
    # runtime autosuspend. Keep only this internal fingerprint device awake.
    services.udev.extraRules = lib.mkIf cfg.keepAwake (
      lib.mkAfter ''
        ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="27c6", ATTR{idProduct}=="609c", TEST=="power/control", ATTR{power/control}="on"
      ''
    );

    # Plasma keeps a dedicated fingerprint PAM worker alive while locked.
    # Stopping fprintd here would terminate that worker across suspend. Other
    # desktops retain the stop-before-sleep workaround.
    powerManagement.powerDownCommands =
      lib.mkIf (cfg.stopBeforeSleep && !config.services.desktopManager.plasma6.enable)
        (
          lib.mkAfter ''
            ${pkgs.systemd}/bin/systemctl stop fprintd.service || true
          ''
        );

    # Discover the controller at boot so recovery still knows the validated
    # target while the USB child device is missing. This is the declarative
    # equivalent of Framework's Fingerprint-Wake-Workaround installer.
    systemd.services.framework-fingerprint-controller = lib.mkIf (cfg.resetMode != "disabled") {
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

    # Conservative profiles recover after resume. Plasma asks D-Bus to start
    # fprintd as soon as the user session thaws, so order recovery first.
    systemd.services.framework-fingerprint-wake =
      lib.mkIf
        (builtins.elem cfg.resetMode [
          "when-missing"
          "always"
        ])
        {
          description = "Restore the Framework fingerprint reader after resume";
          wantedBy = sleepTargets;
          wants = [ "framework-fingerprint-controller.service" ];
          after = sleepTargets ++ [ "framework-fingerprint-controller.service" ];
          before = [ "fprintd.service" ];
          serviceConfig = {
            Type = "oneshot";
            RuntimeDirectory = "framework-fingerprint-wake";
            RuntimeDirectoryPreserve = true;
            ExecStart = "${fingerprintWake}/bin/framework-fingerprint-wake recover";
          };
        };

    # On the verified AMD topology the xHCI controller is dedicated to the
    # reader. Reset it immediately before fprintd opens the device, mitigating
    # both real suspend and the observed lock/idle failure without resetting
    # the controller when fingerprint authentication is not requested.
    systemd.services.fprintd = lib.mkIf (cfg.resetMode == "before-use") {
      wants = [ "framework-fingerprint-controller.service" ];
      after = [ "framework-fingerprint-controller.service" ];
      serviceConfig.ExecStartPre = [
        "${fingerprintWake}/bin/framework-fingerprint-wake prepare"
      ];
    };

    # Keep sudo and Plasma's parallel lock-screen worker enabled. Disable
    # fingerprint authentication in the sequential password stacks below so
    # they do not wait for a scan before accepting a password.
    #
    # Plasma runs the separate "kde-fingerprint" PAM service in parallel with
    # the password prompt. Keep that worker alive for the lifetime of the lock
    # screen so repeated suspend cycles cannot strand it in a timed-out state.
    security.pam.services = {
      "kde-fingerprint".rules.auth.fprintd.settings =
        lib.mkIf config.services.desktopManager.plasma6.enable
          {
            timeout = -1;
            "max-tries" = -1;
          };

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
  };
}
