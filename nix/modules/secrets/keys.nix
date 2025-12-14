rec {
  # Add user keys from ~/.ssh for desktop machines
  inwin-tower-tghanken = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICh921bOnrGEySjw/eRrUAj1UbV2sf1YIcm5X74r6gTh";
  nixos-thinkpad-tghanken = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOHrxGPx3dgap4sUwWyHbQsMJiv9tSNG05BEMNkNLDZF";
  pegasus-tghanken = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEfBG0uOaa7KtZIGl20khDyj1VrUuAzoJUEN7nfkscBa";
  tghanken = [inwin-tower-tghanken nixos-thinkpad-tghanken pegasus-tghanken];

  users = tghanken;

  # Add machine keys from /etc/ssh
  inwin-tower = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/iE8w8saXDau1F/BQ5IktJPQO3MhRT1+1e5UsQt/n0";
  nixos-thinkpad = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEiccufbIo8bYbn5n7PpR1IAFmup53P6nn8IyYfkJfd0";
  pegasus = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfLX3asu3yZIEMlHtEb9byRapy65kGItWsipfyRHToO";
  brontes = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIALYW2t7dYik9EY2nAyA6Imj0r0RX25Cmah8rNbdMdKQ";

  machines = [
    inwin-tower
    nixos-thinkpad
    pegasus
    brontes
  ];

  all = users ++ machines;
}
