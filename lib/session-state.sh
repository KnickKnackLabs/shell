#!/usr/bin/env bash

# Normalize zmx's last-task record into Shell's live-session contract.
# A listed, reachable zmx session owns a persistent shell even after its last
# managed task exits. The terminal foreground process group distinguishes an
# idle shell prompt from a later process launched through raw PTY input.

shell_foreground_json() {
  local shell_pid="$1"
  local groups shell_pgid terminal_pgid foreground_pid

  case "$shell_pid" in
    ''|*[!0-9]*)
      jq -cn '{status: "unknown"}'
      return
    ;;
  esac

  if ! groups=$(ps -p "$shell_pid" -o pgid= -o tpgid= 2>/dev/null); then
    jq -cn '{status: "unknown"}'
    return
  fi

  read -r shell_pgid terminal_pgid <<< "$groups"
  case "$shell_pgid:$terminal_pgid" in
    *[!0-9:]*|:*)
      jq -cn '{status: "unknown"}'
      return
    ;;
  esac

  if [ "$terminal_pgid" -le 0 ]; then
    jq -cn '{status: "unknown"}'
    return
  fi

  if [ "$terminal_pgid" -eq "$shell_pgid" ]; then
    jq -cn '{status: "idle"}'
    return
  fi

  foreground_pid=$(ps -axo pid=,pgid= 2>/dev/null | awk -v target="$terminal_pgid" '
    $2 == target && first == "" { first = $1 }
    END { if (first != "") print first }
  ')

  case "$foreground_pid" in
    ''|*[!0-9]*)
      jq -cn --argjson pgrp "$terminal_pgid" '{status: "running", pgrp: $pgrp}'
    ;;
    *)
      jq -cn --argjson pid "$foreground_pid" --argjson pgrp "$terminal_pgid" \
        '{status: "running", pid: $pid, pgrp: $pgrp}'
    ;;
  esac
}

shell_normalize_session_json() {
  local session_json="$1"
  local name raw_status shell_pid clients exit_code
  local pty_status foreground_json foreground_status status last_task_json

  name=$(printf '%s' "$session_json" | jq -r '.name // ""')
  raw_status=$(printf '%s' "$session_json" | jq -r '.status // ""')
  shell_pid=$(printf '%s' "$session_json" | jq -r '.pid // 0')
  clients=$(printf '%s' "$session_json" | jq -r '.clients // 0')
  exit_code=$(printf '%s' "$session_json" | jq -r '.exit_code // empty')

  case "$raw_status" in
    exited*)
      if [ -n "$exit_code" ]; then
        last_task_json=$(jq -cn \
          --arg raw_status "$raw_status" \
          --argjson exit_code "$exit_code" \
          '{status: "exited", raw_status: $raw_status, exit_code: $exit_code}')
      else
        last_task_json=$(jq -cn \
          --arg raw_status "$raw_status" \
          '{status: "exited", raw_status: $raw_status}')
      fi
    ;;
    unreachable)
      last_task_json=$(jq -cn --arg raw_status "$raw_status" \
        '{status: "unknown", raw_status: $raw_status}')
    ;;
    '')
      last_task_json=$(jq -cn '{status: "unknown", raw_status: ""}')
    ;;
    *)
      last_task_json=$(jq -cn --arg raw_status "$raw_status" \
        '{status: "running", raw_status: $raw_status}')
    ;;
  esac

  if [ "$raw_status" = "unreachable" ]; then
    pty_status="unreachable"
    foreground_json=$(jq -cn '{status: "unknown"}')
    status="unreachable"
  else
    pty_status="alive"
    foreground_json=$(shell_foreground_json "$shell_pid")
    foreground_status=$(printf '%s' "$foreground_json" | jq -r '.status')

    case "$raw_status:$foreground_status" in
      exited*:running)
        status="running"
      ;;
      exited*:idle)
        status="idle"
      ;;
      exited*:*)
        status="unknown"
      ;;
      :*)
        status="unknown"
      ;;
      *)
        status="running"
      ;;
    esac
  fi

  jq -cn \
    --argjson source "$session_json" \
    --arg name "$name" \
    --arg status "$status" \
    --arg pty_status "$pty_status" \
    --argjson clients "$clients" \
    --argjson foreground "$foreground_json" \
    --argjson last_task "$last_task_json" \
    '{
      name: $name,
      status: $status,
      pid: ($source.pid // 0),
      clients: $clients,
      created: ($source.created // $source.created_at // 0),
      ended: (if $last_task.status == "exited" then ($source.ended // $source.ended_at // $source.created_at // 1) else -1 end),
      exit_code: (if $last_task.status == "exited" then ($source.exit_code // -1) else -1 end),
      cmd: ($source.cmd // ""),
      pty: {status: $pty_status, pid: ($source.pid // 0)},
      foreground: $foreground,
      last_task: $last_task
    }'
}

shell_status_summary() {
  local normalized_json="$1"
  local status clients foreground_pid last_task_status exit_code

  status=$(printf '%s' "$normalized_json" | jq -r '.status')
  clients=$(printf '%s' "$normalized_json" | jq -r '.clients')
  foreground_pid=$(printf '%s' "$normalized_json" | jq -r '.foreground.pid // empty')
  last_task_status=$(printf '%s' "$normalized_json" | jq -r '.last_task.status')
  exit_code=$(printf '%s' "$normalized_json" | jq -r '.last_task.exit_code // empty')

  printf '%s' "$status"
  if [ "$status" = "running" ] && [ -n "$foreground_pid" ]; then
    printf ' (foreground pid %s' "$foreground_pid"
  else
    printf ' ('
  fi

  if [ "$last_task_status" = "exited" ] && [ -n "$exit_code" ]; then
    if [ "$status" = "running" ] && [ -n "$foreground_pid" ]; then
      printf '; last task exited %s' "$exit_code"
    else
      printf 'last task exited %s' "$exit_code"
    fi
  else
    if [ "$status" = "running" ] && [ -n "$foreground_pid" ]; then
      printf '; last task %s' "$last_task_status"
    else
      printf 'last task %s' "$last_task_status"
    fi
  fi

  printf '; clients %s)\n' "$clients"
}
