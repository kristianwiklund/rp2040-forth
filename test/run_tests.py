#!/usr/bin/env python3
"""
Automated test runner for rp2040-forth.

Usage:
    python test/run_tests.py [--port /dev/ttyACM0] [--baud 115200]
                             [--section 3] [--id 3.4]
                             [--log test/results/run.log]
                             [--timeout 5] [--no-color]
"""

import argparse
import datetime
import os
import re
import sys
import time

try:
    import serial
except ImportError:
    sys.exit("pyserial not installed — run: pip install pyserial")

# Ensure the test/ directory is on the path so `cases` can be imported
sys.path.insert(0, os.path.dirname(__file__))
from cases import ALL_TESTS

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------

RESET = "\033[0m"
GREEN = "\033[32m"
RED   = "\033[31m"
YELLOW= "\033[33m"
CYAN  = "\033[36m"
BOLD  = "\033[1m"

def _colour(text, code, use_colour):
    return f"{code}{text}{RESET}" if use_colour else text


# ---------------------------------------------------------------------------
# Serial helpers
# ---------------------------------------------------------------------------

def find_port():
    """
    Auto-detect the RP2040 serial port.

    Strategy (in order):
      1. Match by Raspberry Pi USB vendor ID (0x2E8A).
      2. Match by description containing "Pico" or "RP2" (case-insensitive).
      3. On Windows, match "USB Serial Device" — the generic CDC driver label.

    Returns the port name string, or exits with a helpful listing if none found.
    """
    from serial.tools import list_ports

    candidates = list_ports.comports()

    # VID 0x2E8A = Raspberry Pi
    by_vid = [p for p in candidates if p.vid == 0x2E8A]
    if by_vid:
        if len(by_vid) > 1:
            names = ", ".join(p.device for p in by_vid)
            print(f"Multiple RP2040 ports found ({names}); using {by_vid[0].device}")
        return by_vid[0].device

    # Description fallback (covers generic CDC drivers on Windows)
    desc_keywords = ("pico", "rp2", "usb serial device")
    by_desc = [p for p in candidates
               if any(kw in (p.description or "").lower() for kw in desc_keywords)]
    if by_desc:
        if len(by_desc) > 1:
            names = ", ".join(p.device for p in by_desc)
            print(f"Multiple candidate ports ({names}); using {by_desc[0].device}")
        return by_desc[0].device

    # Nothing found — print a helpful list and exit
    if candidates:
        listing = "\n".join(
            f"  {p.device:<12} {p.description or '(no description)'}"
            for p in candidates
        )
        sys.exit(
            f"No RP2040 port detected. Available ports:\n{listing}\n"
            "Use --port <name> to specify one explicitly."
        )
    else:
        sys.exit("No serial ports found. Is the device connected?")


def connect(port, baud):
    """Open serial port with a short per-read timeout."""
    ser = serial.Serial(port, baud, bytesize=8, parity='N', stopbits=1,
                        timeout=0.1)
    return ser


def flush_boot(ser, silent_for=1.5):
    """
    Drain all incoming bytes until the line is silent for `silent_for` seconds.
    The device echoes all of forthdefs during startup before accepting input.
    """
    deadline = time.monotonic() + silent_for
    while True:
        chunk = ser.read(256)
        if chunk:
            deadline = time.monotonic() + silent_for
        elif time.monotonic() >= deadline:
            break


def send_command(ser, line, timeout=5.0):
    """
    Send `line` + newline, accumulate bytes until buffer ends with ok\\n.
    Returns the raw received string.
    Raises TimeoutError if ok\\n is not seen within `timeout` seconds.
    """
    ser.write((line + "\n").encode())
    buf = b""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        chunk = ser.read(256)
        if chunk:
            buf += chunk
            if buf.endswith(b"ok\n") or buf.endswith(b"ok\r\n"):
                break
    else:
        raise TimeoutError(buf.decode(errors="replace"))
    return buf.decode(errors="replace")


def send_error_command(ser, line, timeout=2.0):
    """
    Like send_command but also terminates on `timeout` seconds of silence
    (for error cases where no ok\\n arrives).
    """
    ser.write((line + "\n").encode())
    buf = b""
    deadline = time.monotonic() + timeout
    while True:
        chunk = ser.read(256)
        if chunk:
            buf += chunk
            deadline = time.monotonic() + timeout
            if buf.endswith(b"ok\n") or buf.endswith(b"ok\r\n"):
                break
        elif time.monotonic() >= deadline:
            break
    return buf.decode(errors="replace")


def extract_output(raw, input_line):
    """
    Strip the echoed input and trailing ok\\n from raw serial output.
    Returns just the word-output portion.

    Protocol (one char at a time echo):
        sent:     42 .\\n
        received: 42 .\\n42 ok\\n
    So everything after the first \\n and before the final ok\\n is output.
    """
    # Normalise line endings
    text = raw.replace("\r", "")
    # Skip echoed input (everything up to and including the first newline)
    nl = text.find("\n")
    if nl == -1:
        return text.strip()
    after_echo = text[nl + 1:]
    # The interpreter emits one blank line between the input echo and output;
    # strip that single structural newline so it does not pollute comparisons.
    if after_echo.startswith("\n"):
        after_echo = after_echo[1:]
    # Strip trailing "ok\n"
    if after_echo.endswith("ok\n"):
        after_echo = after_echo[:-3]
    return after_echo


def match_output(actual, test):
    """Return True if actual output satisfies the test's match strategy."""
    strategy = test["match"]
    expected = test.get("expect") or ""
    if strategy == "exact":
        return actual.rstrip() == expected.rstrip()
    if strategy == "contains":
        return expected in actual
    if strategy == "regex":
        return bool(re.search(expected, actual))
    if strategy == "any":
        return len(actual.strip()) > 0
    if strategy == "error":
        return expected in actual
    return False  # unknown strategy → fail


# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------

def run_one(ser, test, sent_setups, args):
    """
    Execute a single test case.

    Returns a dict with keys: status, actual, test.
    status is one of: PASS, FAIL, SKIP, TOUT
    """
    if test["match"] == "skip":
        return {"status": "SKIP", "actual": None, "test": test}

    # Send setup commands (deduplicated across the whole run)
    for cmd in test.get("setup", []):
        if cmd not in sent_setups:
            try:
                send_command(ser, cmd, timeout=args.timeout)
            except TimeoutError as e:
                return {"status": "TOUT",
                        "actual": f"[setup timeout] {e}",
                        "test": test}
            sent_setups.add(cmd)

    # Send the actual test input
    try:
        if test["match"] == "error":
            raw = send_error_command(ser, test["input"], timeout=2.0)
        else:
            raw = send_command(ser, test["input"], timeout=args.timeout)
    except TimeoutError as e:
        return {"status": "TOUT", "actual": str(e), "test": test}

    # For error tests, match against the full raw buffer
    if test["match"] == "error":
        ok = match_output(raw, test)
    else:
        actual = extract_output(raw, test["input"])
        ok = match_output(actual, test)

    actual_display = raw if test["match"] == "error" else extract_output(raw, test["input"])
    return {
        "status": "PASS" if ok else "FAIL",
        "actual": actual_display,
        "test": test,
    }


# ---------------------------------------------------------------------------
# Formatting
# ---------------------------------------------------------------------------

def format_result(result, use_colour):
    status = result["status"]
    test   = result["test"]
    actual = result["actual"]

    colour_map = {
        "PASS": GREEN,
        "FAIL": RED,
        "SKIP": YELLOW,
        "TOUT": CYAN,
    }
    label = _colour(f"  {status}", colour_map.get(status, ""), use_colour)

    tid   = test["id"].ljust(6)
    inp   = test["input"][:40].ljust(40)

    if status == "PASS":
        detail = f'-> "{actual.rstrip()}"'
    elif status == "FAIL":
        got  = repr(actual.rstrip()) if actual is not None else "n/a"
        want = repr(test.get("expect", ""))
        detail = f"got {got} expected {want}"
    elif status == "SKIP":
        detail = f"known failure ({test['note']})"
    else:  # TOUT
        detail = f"no ok within {test.get('timeout', 5)}s"

    return f"{label}  {tid}  {inp}  {detail}"


# ---------------------------------------------------------------------------
# Boot verification ping
# ---------------------------------------------------------------------------

def verify_ping(ser, timeout=3.0):
    """
    Send `1 .` and check we get `1 ok\\n` back within `timeout` seconds.
    Returns (ok: bool, raw: str).
    """
    try:
        raw = send_command(ser, "1 .", timeout=timeout)
        out = extract_output(raw, "1 .")
        return out.rstrip() == "1", raw
    except TimeoutError as e:
        return False, str(e)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="rp2040-forth automated test runner")
    parser.add_argument("--port",    default=None,
                        help="Serial port (default: auto-detect RP2040)")
    parser.add_argument("--baud",    default=115200, type=int, help="Baud rate")
    parser.add_argument("--section", type=int, default=None,
                        help="Run only tests from this section number")
    parser.add_argument("--id",      default=None,
                        help="Run only the test with this id (e.g. 3.4)")
    parser.add_argument("--log",     default=None,
                        help="Write results to this log file (default: auto in test/results/)")
    parser.add_argument("--timeout", default=5.0, type=float,
                        help="Seconds to wait for ok\\n per command")
    parser.add_argument("--no-color", dest="color", action="store_false",
                        help="Disable ANSI colour output")
    args = parser.parse_args()

    # Build filtered test list
    tests = ALL_TESTS
    if args.section is not None:
        prefix = f"{args.section}."
        tests = [t for t in tests if t["id"].startswith(prefix)]
    if args.id is not None:
        tests = [t for t in tests if t["id"] == args.id]

    if not tests:
        sys.exit("No tests matched the filter.")

    # Prepare log file
    if args.log is None:
        results_dir = os.path.join(os.path.dirname(__file__), "results")
        os.makedirs(results_dir, exist_ok=True)
        ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        args.log = os.path.join(results_dir, f"{ts}.log")

    if args.port is None:
        args.port = find_port()
        print(f"Auto-detected port: {args.port}")

    print(f"Connecting to {args.port} @ {args.baud}…")
    try:
        ser = connect(args.port, args.baud)
    except serial.SerialException as e:
        sys.exit(f"Cannot open port: {e}")

    print("Waiting for device boot…")
    flush_boot(ser)

    print("Sending ping (1 .)…")
    ok, raw = verify_ping(ser)
    if not ok:
        ser.close()
        sys.exit(f"Ping failed — device not ready.\nRaw: {raw!r}")
    print("Device ready.\n")

    lines = []

    def emit(line):
        print(line)
        lines.append(line)

    sent_setups = set()
    current_section = None
    counts = {"PASS": 0, "FAIL": 0, "SKIP": 0, "TOUT": 0}

    for test in tests:
        if test["section"] != current_section:
            current_section = test["section"]
            hdr = f"\n=== {test['id'].split('.')[0]}. {current_section} ==="
            emit(_colour(hdr, BOLD, args.color))

        result = run_one(ser, test, sent_setups, args)
        counts[result["status"]] += 1
        emit(format_result(result, args.color))

    ser.close()

    # Summary
    total = sum(counts.values())
    summary = (
        f"\nPassed: {counts['PASS']}  "
        f"Failed: {counts['FAIL']}  "
        f"Skipped: {counts['SKIP']}  "
        f"Timeout: {counts['TOUT']}  "
        f"Total: {total}"
    )
    emit(summary)

    # Write log
    ts_full = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(args.log, "w", encoding="utf-8") as f:
        f.write(f"rp2040-forth test run — {ts_full}\n")
        f.write(f"Port: {args.port}  Baud: {args.baud}\n\n")
        for line in lines:
            # Strip ANSI codes for the log file
            clean = re.sub(r"\033\[[0-9;]*m", "", line)
            f.write(clean + "\n")

    print(f"\nLog written to: {args.log}")

    sys.exit(0 if counts["FAIL"] == 0 and counts["TOUT"] == 0 else 1)


if __name__ == "__main__":
    main()
