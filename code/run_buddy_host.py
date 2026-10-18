#!/usr/bin/env python3
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
logs = root / "tests" / "results"
logs.mkdir(exist_ok=True)
modes = ["normal", "alloc-zero", "init-zero", "init-overlap", "init-outside",
         "free-outside", "free-reserved", "free-zero", "free-interior",
         "free-wrong-size", "free-unaligned", "double-free", "init-live"]
lines = []
with tempfile.TemporaryDirectory(prefix="ucore-buddy-") as tmp:
    binary = str(Path(tmp) / "buddy_host")
    subprocess.run(["gcc", "-std=gnu99", "-Wall", "-Wextra", "-Werror", "-O1", "-g",
                    "-fno-builtin", "-fno-pie", "-no-pie", "-fsanitize=address,undefined",
                    "-Ilibs", "-Ikern/debug", "-Ikern/mm", "-Ikern/arch",
                    "tests/buddy_host.c", "kern/mm/buddy_pmm.c", "-o", binary], cwd=root, check=True)
    env = dict(os.environ, ASAN_OPTIONS="detect_leaks=1:halt_on_error=1",
               UBSAN_OPTIONS="halt_on_error=1")
    for mode in modes:
        result = subprocess.run([binary, mode], capture_output=True, text=True, env=env, timeout=30)
        output = result.stdout + result.stderr
        expected = 0 if mode == "normal" else 86
        ok = result.returncode == expected
        if mode != "normal":
            ok = ok and "BUDDY_TEST_ASSERT kern/mm/buddy_pmm.c:" in output
        ok = ok and "ERROR: AddressSanitizer" not in output and "runtime error:" not in output
        line = f"{'PASS' if ok else 'FAIL'} buddy/{mode} exit={result.returncode}"
        lines.append(line + "\n" + output)
        print(line)
        (logs / "buddy-host.log").write_text("\n".join(lines), encoding="utf-8")
        if not ok:
            raise SystemExit(output or line)
print("All 13 Buddy scenarios passed with ASan/UBSan.")
