{ ... }:

{
  assertions = [
    {
      assertion = false;
      message = ''
        Replace hosts/framework-intel-core-ultra/hardware-configuration.nix with a generated hardware config.

        From the NixOS installer, after mounting your target system at /mnt:
          ./scripts/install-host.sh framework-intel-core-ultra
      '';
    }
  ];
}
