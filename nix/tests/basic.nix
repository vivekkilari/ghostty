{
  name = "basic";

  nodes.machine = {
    config,
    pkgs,
    ...
  }: {
    users.users.alice = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      packages = with pkgs; [
        firefox
        (pkgs.callPackage ../package.nix {})
      ];
    };

    system.stateVersion = "24.11";
  };

  testScript = ''
    machine.wait_for_unit("default.target")
    machine.succeed("su -- alice -c 'which firefox'")
    machine.fail("su -- root -c 'which firefox'")
  '';
}
