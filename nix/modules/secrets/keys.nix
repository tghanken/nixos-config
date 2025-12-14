rec {
  # Add user keys from ~/.ssh for desktop machines
  inwin-tower-tghanken = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICh921bOnrGEySjw/eRrUAj1UbV2sf1YIcm5X74r6gTh";
  nixos-thinkpad-tghanken = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOHrxGPx3dgap4sUwWyHbQsMJiv9tSNG05BEMNkNLDZF";
  hercules-tghanken = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJreyi2q5YRIEGh9egQGZwRri4lWJ8VGo4rk0zdEM9iS";
  pegasus-tghanken = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEfBG0uOaa7KtZIGl20khDyj1VrUuAzoJUEN7nfkscBa";

  tghanken = [
    inwin-tower-tghanken
    nixos-thinkpad-tghanken
    hercules-tghanken
    pegasus-tghanken
  ];

  # Array of all users
  users = tghanken;

  # Add machine keys from /etc/ssh
  # Clients
  inwin-tower = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/iE8w8saXDau1F/BQ5IktJPQO3MhRT1+1e5UsQt/n0";
  nixos-thinkpad = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEiccufbIo8bYbn5n7PpR1IAFmup53P6nn8IyYfkJfd0";
  hercules = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDBYUEGFFy31pryUktRRi6/VGzzDdPpyMicYH7UOkkTA";
  pegasus = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfLX3asu3yZIEMlHtEb9byRapy65kGItWsipfyRHToO";

  clients = [
    inwin-tower
    nixos-thinkpad
    hercules
    pegasus
  ];

  # Local Servers
  arges = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBQ3ODJklAfTFAdRUJCs8fyhPpaH8ynrqfUXZlj3J4Aa";
  brontes = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIALYW2t7dYik9EY2nAyA6Imj0r0RX25Cmah8rNbdMdKQ";
  steropes = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH4cuR6nV2E8ACT/Tw3KVPXV9k2dzmJ3gVcx0aLS4UdO";

  local-servers = [
    arges
    brontes
    steropes
  ];

  # Array of all machines
  servers = local-servers;
  machines = clients ++ servers;

  # Array of all keys
  all = users ++ machines;
}
