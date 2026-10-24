#!/usr/bin/env python3
# 2410691：SLUB 测试运行脚本 修改部分 开始
"""Run positive cases and isolated assertion cases with two real PMMs and a mock."""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
logs = root / "tests" / "results"
logs.mkdir(exist_ok=True)
modes = ["normal", "before-init", "foreign", "raw-page", "large-interior",
         "reinit-live", "interior", "double-live-slab", "double-released-slab"]
lines = []
with tempfile.TemporaryDirectory(prefix="ucore-slub-") as tmp:
    binary = str(Path(tmp) / "slub_host")
    flags = ["-std=gnu99", "-Wall", "-Wextra", "-Werror", "-O1", "-g",
           "-fno-builtin", "-fno-pie", "-no-pie", "-fsanitize=address,undefined",
           "-Ilibs", "-Ikern/debug", "-Ikern/mm", "-Ikern/arch"]
    sources = ["tests/slub_host.c", "kern/mm/slub.c", "kern/mm/slub_check.c",
               "kern/mm/buddy_pmm.c", "kern/mm/default_pmm.c"]
    objects = []
    for i, source in enumerate(sources):
        obj = str(Path(tmp) / f"{i}.o")
        # Existing default_check has an int/size_t comparison under -Wextra.
        # Keep its warning visible without editing the course's fixed tests.
        extra = ["-Wno-error=sign-compare"] if source.endswith("default_pmm.c") else []
        subprocess.run(["gcc", *flags, *extra, "-c", source, "-o", obj], cwd=root, check=True)
        objects.append(obj)
    subprocess.run(["gcc", "-no-pie", "-fsanitize=address,undefined", *objects,
                    "-o", binary], cwd=root, check=True)
    env = dict(os.environ, ASAN_OPTIONS="detect_leaks=1:halt_on_error=1",
               UBSAN_OPTIONS="halt_on_error=1")
    for backend in ["first-fit", "buddy", "rounded"]:
        for mode in modes:
            result = subprocess.run([binary, backend, mode], text=True,
                                    capture_output=True, env=env, timeout=30)
            expected = 0 if mode == "normal" else 86
            text = result.stdout + result.stderr
            ok = result.returncode == expected
            if mode != "normal":
                ok = ok and "EXPECTED_OR_TEST_ASSERT kern/mm/slub.c:" in text
            ok = ok and "ERROR: AddressSanitizer" not in text and "runtime error:" not in text
            line = f"{'PASS' if ok else 'FAIL'} {backend}/{mode} exit={result.returncode}"
            lines.append(line + "\n" + text)
            print(line)
            (logs / "slub-host.log").write_text("\n".join(lines), encoding="utf-8")
            if not ok:
                raise SystemExit(text or line)
print(f"All {len(lines)} SLUB cases passed with ASan/UBSan. Log: {logs / 'slub-host.log'}")
# 2410691：SLUB 测试运行脚本 修改部分 结束
