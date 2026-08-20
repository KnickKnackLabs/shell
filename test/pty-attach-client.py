#!/usr/bin/env python3
"""Hold one real zmx attach client open on a disposable pseudo-terminal."""

import os
import pty
import select
import signal
import subprocess
import sys

name, ready_path = sys.argv[1:]
master, slave = pty.openpty()
env = os.environ.copy()
# A supervising agent desk may export its own current zmx session. The fixture
# must honor the explicit test name instead of inheriting that ambient target.
env.pop("ZMX_SESSION", None)
client = subprocess.Popen(
    ["zmx", "attach", name],
    stdin=slave,
    stdout=slave,
    stderr=slave,
    start_new_session=True,
    env=env,
)
os.close(slave)
running = True


def stop(_signum: int, _frame: object) -> None:
    global running
    running = False


signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
open(ready_path, "w", encoding="utf-8").close()

try:
    while running and client.poll() is None:
        readable, _, _ = select.select([master], [], [], 0.1)
        if readable:
            try:
                os.read(master, 4096)
            except OSError:
                break
finally:
    if client.poll() is None:
        os.killpg(client.pid, signal.SIGTERM)
        try:
            client.wait(timeout=2)
        except subprocess.TimeoutExpired:
            os.killpg(client.pid, signal.SIGKILL)
            client.wait()
    os.close(master)
