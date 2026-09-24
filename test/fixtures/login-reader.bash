# Login-only synthetic terminal reader. Never evaluate input it consumes.
for (( read_number = 0; read_number < ${SHELL_STARTUP_READS:-1}; read_number++ )); do
  startup_input=
  if IFS= read -r -t 2 startup_input </dev/tty; then :; fi
  printf '%s\n' "$startup_input" >> "$SHELL_STARTUP_TEST_DIR/consumed"
done
unset startup_input
printf 'startup\n' >> "$SHELL_STARTUP_TEST_DIR/events"
PS1='shell-test$ '
