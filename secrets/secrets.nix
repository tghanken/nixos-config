let
  inwin-tower = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/iE8w8saXDau1F/BQ5IktJPQO3MhRT1+1e5UsQt/n0";
  nixos-thinkpad = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEiccufbIo8bYbn5n7PpR1IAFmup53P6nn8IyYfkJfd0";
  machines = [inwin-tower nixos-thinkpad];
in {
  "tailscale_key.age".publicKeys = machines;
}
