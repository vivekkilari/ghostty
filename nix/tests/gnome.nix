{
  name = "gnome";

  nodes.machine = {
    config,
    pkgs,
    ...
  }: {
    users.users.alice = {
      isNormalUser = true;
      password = "alice";
      extraGroups = ["wheel"];
      packages = with pkgs; [
        (pkgs.callPackage ../package.nix {})
      ];
    };

    services.xserver.enable = true;

    services.xserver.displayManager = {
      gdm.enable = true;
      gdm.debug = true;
    };

    services.displayManager.autoLogin = {
      enable = true;
      user = "alice";
    };

    services.xserver.desktopManager.gnome.enable = true;
    services.xserver.desktopManager.gnome.debug = true;

    systemd.user.services = {
      "org.gnome.Shell@wayland" = {
        serviceConfig = {
          ExecStart = [
            # Clear the list before overriding it.
            ""
            # Eval API is now internal so Shell needs to run in unsafe mode.
            # TODO: improve test driver so that it supports openqa-like manipulation
            # that would allow us to drop this mess.
            "${pkgs.gnome-shell}/bin/gnome-shell --unsafe-mode"
          ];
        };
      };
    };

    system.stateVersion = "24.11";
  };

  testScript = ''
    machine.wait_for_unit("default.target")
    machine.succeed("su -- alice -c 'which firefox'")
    machine.fail("su -- root -c 'which firefox'")
  '';
}
