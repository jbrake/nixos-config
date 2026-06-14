{ ... }:

{
  assertions = [
    {
      assertion = false;
      message = ''
        Replace hosts/framework-amd-ai-300/hardware-configuration.nix with a generated hardware config.

        From the NixOS installer, after mounting your target system at /mnt:
          ./scripts/install-host.sh framework-amd-ai-300
      '';
    }
  ];
}
