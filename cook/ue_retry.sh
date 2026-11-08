#!/bin/zsh
# Usage: ue_retry.sh <log-prefix> <max-attempts> <success-grep> <UnrealEditor-Cmd args...>
# Retries UnrealEditor-Cmd under CrossOver: the wine create_view assertion crash is intermittent at startup.
wine_bin=/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine
editor_exe='C:\Program Files\Epic Games\UE_5.4\Engine\Binaries\Win64\UnrealEditor-Cmd.exe'
log_prefix=$1; max_attempts=$2; success_pattern=$3; shift 3
for attempt in $(seq 1 $max_attempts); do
  attempt_log="${log_prefix}_try${attempt}.log"
  start_ts=$(date +%s)
  "$wine_bin" --bottle "Epic Games Store" "$editor_exe" "$@" -unattended -nop4 -nosplash -stdout -FullStdOutLogOutput > "$attempt_log" 2>&1
  while pgrep -f "UnrealEditor-Cmd" >/dev/null; do sleep 10; done
  elapsed=$(( $(date +%s) - start_ts ))
  if grep -q "$success_pattern" "$attempt_log"; then
    echo "ATTEMPT $attempt: SUCCESS in ${elapsed}s  log=$attempt_log"
    exit 0
  fi
  crash=$(grep -c "Assertion failed: (view->protect & VPROT_SYSTEM)" "$attempt_log")
  echo "ATTEMPT $attempt: FAILED in ${elapsed}s (wine create_view assertion: $crash)  log=$attempt_log"
  if [ "$crash" = "0" ]; then
    grep -nE "Error|error:|Traceback|Exception" "$attempt_log" | tail -15 | cut -c1-250
    exit 2
  fi
done
exit 1
