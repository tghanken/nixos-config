{
  pkgs,
  flakeSrc,
  name,
}:
pkgs.writeShellApplication {
  inherit name;
  runtimeInputs = [
    pkgs.jq
    pkgs.nix-fast-build
  ];
  text = ''
    set -euo pipefail

    ROOT="${flakeSrc}"
    SYSTEM="$(nix eval --raw --impure --expr builtins.currentSystem)"
    FLAKE_REF="path:$ROOT#checks.$SYSTEM"
    RESULT="$(mktemp /tmp/${name}-result.XXXXXX.json)"
    LOG="$(mktemp /tmp/${name}.XXXXXX.log)"
    trap 'rm -f "$RESULT"' EXIT

    ci_active() {
      case "''${CI:-}" in
        0|false|False|FALSE|"") return 1 ;;
        *) return 0 ;;
      esac
    }

    NFB_ARGS=(
      --no-nom
      --no-link
      --flake "$FLAKE_REF"
      --result-format json
      --result-file "$RESULT"
    )

    set +e
    if ci_active; then
      nix-fast-build "''${NFB_ARGS[@]}" "$@" 2>&1 | tee "$LOG"
      EXIT=''${PIPESTATUS[0]}
      TRUNC_N=0
    else
      nix-fast-build "''${NFB_ARGS[@]}" "$@" >"$LOG" 2>&1
      EXIT=$?
      TRUNC_N=200
    fi
    set -e

    if [[ ! -s "$RESULT" ]]; then
      echo "status: error"
      echo "exit: $EXIT"
      echo "log: $LOG"
      echo "root: $ROOT"
      echo "flake: $FLAKE_REF"
      echo
      echo "error: nix-fast-build produced no JSON result file"
      if [[ -s "$LOG" ]]; then
        echo "log_tail:"
        tail -n 40 "$LOG" | sed 's/^/  /'
      fi
      if [[ -n "$EXIT" ]]; then
        exit "$EXIT"
      fi
      exit 1
    fi

    cp "$RESULT" "$LOG.json"

    jq -r --argjson exit "$EXIT" --argjson trunc_n "$TRUNC_N" '
      def trunc($n):
        if $n == 0 then .
        elif type == "string" and (length > $n) then .[0:$n-3] + "..."
        else . end;
      .results // [] as $r
      | ($r | map(select(.type == "BUILD" or .type == "EVAL"))) as $jobs
      | ($jobs | map(select(.success == true)) | length) as $ok
      | ($jobs | map(select(.success != true))) as $bad
      | [
          (if $exit == 0 and ($bad | length) == 0 then "status: pass" else "status: fail" end),
          "exit: \($exit)",
          "summary:",
          "  passed: \($ok)",
          "  failed: \($bad | length)",
          (
            if ($bad | length) > 0 then
              (["", "failures:"] + ($bad | map(
                "  - \(.type) \(.attr)" +
                (if .error == null or .error == "" then "" else ": \(.error | tostring | trunc($trunc_n))" end)
              )))
            else [] end
          )
        ]
      | flatten
      | .[]
    ' "$RESULT"

    echo "root: $ROOT"
    echo "flake: $FLAKE_REF"
    echo "log: $LOG"
    echo "json: $LOG.json"
    echo "hint: inspect json/log only if the summary is insufficient"

    if [[ $EXIT -ne 0 ]]; then
      exit "$EXIT"
    fi
    if jq -e '[.results[]? | select((.type == "BUILD" or .type == "EVAL") and (.success != true))] | length == 0' "$RESULT" >/dev/null; then
      exit 0
    fi
    exit 1
  '';
}
