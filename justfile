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
	@agenix edit nix/core/secrets/secret_files/{{SECRET}}.age

alias rs := rekey-secrets
alias es := edit-secret