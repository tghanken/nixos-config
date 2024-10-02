let
  # Add user keys from ~/.ssh
  inwin-tower-tghanken = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICh921bOnrGEySjw/eRrUAj1UbV2sf1YIcm5X74r6gTh";
  nixos-thinkpad-tghanken = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOHrxGPx3dgap4sUwWyHbQsMJiv9tSNG05BEMNkNLDZF";
  tghanken = [inwin-tower-tghanken nixos-thinkpad-tghanken];

  users = tghanken;

  # Add machine keys from /etc/ssh
  inwin-tower = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/iE8w8saXDau1F/BQ5IktJPQO3MhRT1+1e5UsQt/n0";
  nixos-thinkpad = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEiccufbIo8bYbn5n7PpR1IAFmup53P6nn8IyYfkJfd0";

  machines = [inwin-tower nixos-thinkpad];

  all = users ++ machines;
in {
  "tailscale_key.age".publicKeys = all;
}
