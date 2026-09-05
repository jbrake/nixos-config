{
  configurations,
  pkgs,
  lib,
}:
let
  intel = configurations.framework-intel-core-ultra.config;
  amd = configurations.framework-amd-ai-300.config;
  gnome = configurations.framework-intel-core-ultra-gnome.config;
  disabled =
    (configurations.framework-intel-core-ultra-gnome.extendModules {
      modules = [
        {
          jbrake.frameworkFingerprint = {
            resetMode = lib.mkForce "disabled";
            keepAwake = lib.mkForce false;
            stopBeforeSleep = lib.mkForce false;
          };
        }
      ];
    }).config;
  stopsFprintd = config: lib.hasInfix "stop fprintd.service" config.powerManagement.powerDownCommands;
in
# Check actual merged host policies and the retirement path, without touching
# hardware. Authentication remains available when every workaround is off.
assert intel.jbrake.frameworkFingerprint.resetMode == "when-missing";
assert intel.systemd.services ? framework-fingerprint-wake;
assert amd.jbrake.frameworkFingerprint.resetMode == "before-use";
assert !(amd.systemd.services ? framework-fingerprint-wake);
assert builtins.length amd.systemd.services.fprintd.serviceConfig.ExecStartPre > 0;
assert !(stopsFprintd intel);
assert stopsFprintd gnome;
assert disabled.services.fprintd.enable;
assert !(disabled.systemd.services ? framework-fingerprint-controller);
assert !(disabled.systemd.services ? framework-fingerprint-wake);
assert !(stopsFprintd disabled);
assert !(lib.hasInfix "27c6" disabled.services.udev.extraRules);
pkgs.runCommand "fingerprint-policies" { } "touch $out"
