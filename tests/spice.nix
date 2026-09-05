{
  configurations,
  pkgs,
  lib,
}:
let
  enabled = configurations.qemu-vm.config;
  disabled =
    (configurations.qemu-vm.extendModules {
      modules = [ { jbrake.spiceSessionWorkaround.enable = lib.mkForce false; } ];
    }).config;
in
assert enabled.systemd.user.services ? spice-vdagent;
assert enabled.environment.etc ? "xdg/autostart/spice-vdagent.desktop";
assert disabled.services.spice-vdagentd.enable;
assert !(disabled.systemd.user.services ? spice-vdagent);
assert !(disabled.environment.etc ? "xdg/autostart/spice-vdagent.desktop");
pkgs.runCommand "spice-workaround" { } "touch $out"
