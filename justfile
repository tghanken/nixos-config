_default:
  @just --list

[confirm("Are you sure you want to delete all result folders?")]
[group("Utility")]
clean:
	@echo "Cleaning up..."
	@rm -rf result
	@rm -rf result-*

[working-directory: 'nix/modules/secrets/secret_files']
[group("Secrets")]
rekey-secrets:
	@echo "Rekeying secrets..."
	@agenix -r

[working-directory: 'nix/modules/secrets/secret_files']
[group("Secrets")]
edit-secret SECRET:
	@agenix -e encrypted/{{SECRET}}.age

alias rs := rekey-secrets
alias es := edit-secret