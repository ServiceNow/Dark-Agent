#!/usr/bin/env python3
"""
BOF test harness for dark-agent. Auto-discovers compiled BOFs for the
selected platform, loads them into a live callback, and exercises each
one with appropriate test parameters.

Usage:
    python3 test_bofs.py [--os linux|macos] [--skip-load] [--bof NAME[,NAME]]
                         [--callback ID] [--host IP] [--port PORT]
                         [--user USER] [--pass PASS]
"""

import asyncio
import argparse
import json
import os
import sys
import traceback
import time
import getpass
from pathlib import Path

from mythic import mythic, mythic_classes

BOF_BASE = Path(__file__).parent / "Payload_Type/dark_agent/dark_agent/agent_code/output/bofs"
TASK_TIMEOUT = 5
TMP_PREFIX = "/tmp/da_bof_test"

# ---- colour helpers ----
def _c(code, s): return f"\033[{code}m{s}\033[0m"
blu = lambda s: _c(34, s)
yel = lambda s: _c(33, s)
grn = lambda s: _c(32, s)
red = lambda s: _c(31, s)

# ---- BOF test registry ----
# Each entry: (params_dict, description, expects_failure[, skip_on_platforms])
# expects_failure=True means a non-success status is acceptable (crash_test, chown root, etc.)
BOF_REGISTRY = {
    "arp":             ({},                                                              "ARP table",                          False),
    "cat":             ({"filepath": f"{TMP_PREFIX}_cat"},                               "Read test file",                     False),
    "chmod":           ({"mode": "644", "filepath": f"{TMP_PREFIX}_cat"},                "chmod 644 on test file",             False),
    "chown":           ({"owner": "root", "filepath": f"{TMP_PREFIX}_cat"},              "chown root (expect fail non-root)",  True),
    "df":              ({},                                                              "Disk usage",                         False),
    "env":             ({},                                                              "Environment variables",              False),
    "hostname":        ({},                                                              "Hostname",                           False),
    "ifconfig":        ({},                                                              "Network interfaces",                 False),
    "kill":            ({"pid": 99999, "signal": 0},                                    "Signal 0 to non-existent PID",       True),
    "krb_listccaches": ({},                                                              "Kerberos ccache list",               False,  ["linux"]),
    "krb_dump_kirbi":  ({"ccache_path": "/tmp/nonexistent.ccache"},                     "Dump kirbi (expect fail)",           True,   ["linux"]),
    "last":            ({},                                                              "Last logins",                        False),
    "mkdir":           ({"directory": f"{TMP_PREFIX}_dir"},                             "Create test dir",                    False),
    "mounts":          ({},                                                              "Mounted filesystems",                False),
    "mv":              ({"source": f"{TMP_PREFIX}_mv_src",
                         "destination": f"{TMP_PREFIX}_mv_dst"},                        "Move test file",                     False),
    "netstat":         ({},                                                              "Network connections",                False),
    "nslookup":        ({"hostnames": "localhost"},                                      "DNS lookup localhost",               False),
    "portscan":        ({"host": "127.0.0.1", "ports": "22,80,443"},                   "Port scan localhost",                False),
    "ps":              ({},                                                              "Process list",                       False),
    "rm":              ({"filepath": f"{TMP_PREFIX}_rm"},                               "Remove test file",                   False),
    "routes":          ({},                                                              "Routing table",                      False),
    "timestomp":       ({"target_file": f"{TMP_PREFIX}_cat",
                         "source_type": "specific_time",
                         "timestamp": "2024-01-01 00:00:00"},                           "Timestomp test file",                False),
    "uptime":          ({},                                                              "System uptime",                      False),
    "whoami":          ({},                                                              "Current user",                       False),
    "coffee":          ({},                                                              "COFF loader self-test",              True),
}

# Execution order: dependencies must come before consumers
EXEC_ORDER = [
    "whoami", "hostname", "uptime", "env", "ps",
    "netstat", "ifconfig", "routes", "arp", "mounts", "df", "last",
    "nslookup", "portscan",
    "cat", "chmod", "chown", "timestomp",
    "mkdir",
    "mv",
    "rm",
    "kill",
    "krb_listccaches", "krb_dump_kirbi",
    "coffee",
]


# ---- Mythic helpers ----

async def login(host, port, user, pw):
    print(f"[+] Connecting to Mythic at {host}:{port}")
    inst = await mythic.login(
        username=user, password=pw,
        server_ip=host, server_port=str(port),
        timeout=-1
    )
    print("[+] Authenticated")
    return inst


async def select_callback(inst, callback_id):
    if callback_id:
        return {"id": callback_id, "host": "cli-specified"}

    callbacks = await mythic.get_all_callbacks(mythic=inst)
    if not callbacks:
        print("[-] No active callbacks")
        raw = input("[*] Enter callback ID manually (or Enter to exit): ").strip()
        return {"id": int(raw), "host": "manual"} if raw else None

    recent = sorted(callbacks, key=lambda c: int(c["id"]), reverse=True)[:10]
    print(f"\n[+] {len(callbacks)} callback(s), most recent 10:")
    for i, cb in enumerate(recent):
        print(f"  {i+1}. ID={cb['id']}  host={cb.get('host','?')}  user={cb.get('user','?')}")

    if len(recent) == 1:
        return recent[0]

    while True:
        try:
            choice = input(f"[*] Select (1-{len(recent)}) [1]: ").strip() or "1"
            idx = int(choice) - 1
            if 0 <= idx < len(recent):
                return recent[idx]
        except ValueError:
            pass
        print(f"[-] Enter 1-{len(recent)}")


async def wait_for_task(inst, callback_id, task_id, timeout=TASK_TIMEOUT):
    waited = 0
    task_info = {"status": "unknown"}
    while waited < timeout:
        await asyncio.sleep(1)
        waited += 1
        tasks = await mythic.get_all_tasks(mythic=inst, callback_display_id=callback_id)
        task_info = next((t for t in tasks if t["id"] == task_id), task_info)
        status = task_info.get("status", "unknown")
        if status in ("success", "completed", "error", "failed"):
            break
    return task_info


async def issue_and_wait(inst, callback_id, cmd, params, timeout=TASK_TIMEOUT):
    param_str = json.dumps(params) if params else ""
    resp = await mythic.issue_task(
        mythic=inst,
        callback_display_id=callback_id,
        command_name=cmd,
        parameters=param_str
    )
    return await wait_for_task(inst, callback_id, resp["id"], timeout)


# ---- Load phase ----

async def load_bofs(inst, callback_id, bof_dir: Path, names_filter=None):
    print(f"\n{'='*55}")
    print("LOADING BOFs")
    print(f"{'='*55}")
    print(f"[*] BOF directory: {bof_dir}")

    bof_files = sorted(bof_dir.glob("*.o"))
    if not bof_files:
        print("[-] No .o files found in BOF directory")
        return set()

    if names_filter:
        bof_files = [f for f in bof_files if f.stem in names_filter]

    loaded = set()
    for bof_path in bof_files:
        name = bof_path.stem
        print(f"  {blu(f'[*] Loading {name}...')} ", end="", flush=True)
        try:
            with open(bof_path, "rb") as f:
                data = f.read()

            file_uuid = await mythic.register_file(
                mythic=inst,
                filename=bof_path.name,
                contents=data
            )
            if not file_uuid:
                print(red("FAILED (register)"))
                continue

            await mythic.issue_task(
                mythic=inst,
                callback_display_id=callback_id,
                command_name="load",
                parameters=json.dumps({"name": name, "file": file_uuid})
            )
            await asyncio.sleep(1.5)
            print(grn("OK"))
            loaded.add(name)

        except Exception as e:
            print(red(f"ERROR: {e}"))

    print(f"\n[+] Loaded {len(loaded)}/{len(bof_files)} BOFs")
    return loaded


# ---- Test phase ----

async def run_tests(inst, callback_id, loaded_bofs, platform, names_filter=None):
    print(f"\n{'='*55}")
    print("TESTING BOFs")
    print(f"{'='*55}")

    results = []

    ordered = [n for n in EXEC_ORDER if n in loaded_bofs]
    extras = [n for n in sorted(loaded_bofs) if n not in EXEC_ORDER]
    ordered += extras

    if names_filter:
        ordered = [n for n in ordered if n in names_filter]

    for name in ordered:
        entry = BOF_REGISTRY.get(name)
        if not entry:
            # No registry entry: run with no args, treat success as pass
            entry = ({}, f"{name} (no registry entry)", False)

        params, desc, expect_fail = entry[0], entry[1], entry[2]
        skip_on = entry[3] if len(entry) == 4 else []

        if platform in skip_on:
            print(f"  {yel('[~]')} {name:<22} {desc}, {yel('SKIP')}")
            results.append((name, "skip", desc))
            continue

        print(f"  {blu(f'[*]')} {name:<22} {desc}... ", end="", flush=True)

        try:
            task_info = await issue_and_wait(inst, callback_id, name, params)
            status = task_info.get("status", "unknown")
            success = status in ("success", "completed")

            if expect_fail:
                print(yel(f"XFAIL ({status})"))
                results.append((name, "expected_fail", desc))
            elif success:
                print(grn("OK"))
                results.append((name, "pass", desc))
            else:
                err = task_info.get("stderr") or task_info.get("stdout") or status
                if err and len(str(err)) > 80:
                    err = str(err)[:80] + "..."
                print(red(f"FAIL ({err})"))
                results.append((name, "fail", desc))

        except Exception as e:
            print(red(f"ERROR ({e})"))
            results.append((name, "error", desc))


    return results


# ---- Report ----

def print_report(results):
    print(f"\n{'='*55}")
    print("RESULTS")
    print(f"{'='*55}")

    sym_map = {
        "pass":          grn("PASS "),
        "fail":          red("FAIL "),
        "error":         red("ERR  "),
        "skip":          yel("SKIP "),
        "expected_fail": yel("XFAIL"),
    }

    counts = {k: 0 for k in sym_map}
    for name, status, desc in results:
        counts[status] = counts.get(status, 0) + 1
        print(f"  {sym_map.get(status, status)}  {name:<24} {desc}")

    print(f"\n  {grn('PASS')}: {counts['pass']}  "
          f"{red('FAIL')}: {counts['fail']}  "
          f"{red('ERR')}: {counts['error']}  "
          f"{yel('SKIP')}: {counts['skip']}  "
          f"{yel('XFAIL')}: {counts['expected_fail']}")

    if counts["fail"] == 0 and counts["error"] == 0:
        print(f"\n{grn('[+] All tested BOFs passed.')}")
    else:
        total_bad = counts["fail"] + counts["error"]
        print(f"\n{red(f'[-] {total_bad} failure(s): see above.')}")


# ---- Entry point ----

async def main():
    ap = argparse.ArgumentParser(description="dark-agent BOF test harness")
    ap.add_argument("--os", choices=["linux", "macos"], default="linux",
                    help="Target platform (default: linux)")
    ap.add_argument("--skip-load", action="store_true",
                    help="Skip BOF loading: assume already loaded in callback")
    ap.add_argument("--bof", metavar="NAME[,NAME]",
                    help="Comma-separated BOF names to test (default: all)")
    ap.add_argument("--callback", type=int, metavar="ID",
                    help="Callback display ID (skip interactive selection)")
    ap.add_argument("--host", default="127.0.0.1", help="Mythic server IP")
    ap.add_argument("--port", type=int, default=7443, help="Mythic server port")
    ap.add_argument("--user", default="mythic_admin", help="Mythic username")
    ap.add_argument("--pass", dest="password", default="",
                    help="Mythic password (prompted if omitted)")
    args = ap.parse_args()

    if not args.password:
        args.password = getpass.getpass(f"[*] Mythic password for {args.user}: ")

    names_filter = set(args.bof.split(",")) if args.bof else None

    bof_dir = BOF_BASE
    if not bof_dir.exists():
        print(f"[-] BOF directory not found: {bof_dir}")
        sys.exit(1)

    inst = await login(args.host, args.port, args.user, args.password)

    cb = await select_callback(inst, args.callback)
    if not cb:
        print("[-] No callback selected")
        sys.exit(1)

    cb_id = cb["id"]
    print(f"[+] Using callback {cb_id} ({cb.get('host', '?')})")

    if args.skip_load:
        loaded = {f.stem for f in bof_dir.glob("*.o")}
        print(f"[*] Skipping load: treating {len(loaded)} discovered BOFs as loaded")
    else:
        loaded = await load_bofs(inst, cb_id, bof_dir, names_filter)

    results = await run_tests(inst, cb_id, loaded, args.os, names_filter)
    print_report(results)


if __name__ == "__main__":
    asyncio.run(main())
