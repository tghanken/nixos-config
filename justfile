_default:
    @just --list

[confirm("Are you sure you want to delete all result folders?")]
[group("Utility")]
clean:
    @echo "Cleaning up..."
    @rm -rf result
    @rm -rf result-*

[group("Secrets")]
rekey-secrets:
    @echo "Rekeying secrets..."
    @agenix rekey

[group("Secrets")]
edit-secret SECRET:
    @agenix edit nix/core/secrets/secret_files/{{ SECRET }}.age

alias rs := rekey-secrets
alias es := edit-secret

[group("Deployment")]
reimage HOST TARGET="" *FLAGS="":
    @nix run .#reimage-host -- {{ HOST }} {{ TARGET }} {{ FLAGS }}

[group("Deployment")]
ingest-keys *HOSTS="":
    @nix run .#ingest-host-keys -- {{ HOSTS }}

[group("Deployment")]
deploy TARGET="@server":
    @colmena apply --impure --on "{{ TARGET }}" --keep-going

[group("Deployment")]
deploy-all:
    @colmena apply --impure --keep-going

[group("Deployment")]
deploy-dry TARGET="@server":
    @colmena build --impure --on "{{ TARGET }}"

[group("Storage")]
update-disk-layouts:
    @nix run .#update-disk-layouts

alias udl := update-disk-layouts
