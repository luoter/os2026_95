#!/usr/bin/env python3
# 2410691：独立 QEMU 测试运行脚本 修改部分 开始
"""Build and boot an isolated RISC-V kernel without changing teammate modules."""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
logs = root / "tests" / "results"
logs.mkdir(exist_ok=True)
sources = ["kern/init/entry.S", "tests/slub_qemu_main.c", "kern/mm/slub.c",
           "kern/mm/slub_check.c", "kern/mm/default_pmm.c", "kern/mm/buddy_pmm.c",
           "kern/driver/console.c", "kern/libs/stdio.c", "libs/string.c",
           "libs/printfmt.c", "libs/sbi.c"]
flags = ["-mcmodel=medany", "-std=gnu99", "-Wall", "-Werror", "-Wno-unused",
         "-fno-builtin", "-fno-stack-protector", "-nostdinc", "-O2", "-g",
         "-ffunction-sections", "-fdata-sections", "-Ilibs", "-Ikern/debug",
         "-Ikern/mm", "-Ikern/arch", "-Ikern/driver"]
for backend in ["first-fit", "buddy"]:
    with tempfile.TemporaryDirectory(prefix="ucore-slub-qemu-") as tmp:
        tmp = Path(tmp)
        objects = []
        for i, source in enumerate(sources):
            obj = tmp / f"{i}.o"
            define = ["-DTEST_USE_BUDDY"] if backend == "buddy" else []
            compile_source = source
            if source == "kern/init/entry.S":
                # The supplied entry enables Sv39 while still executing at its
                # physical PC, but its table only maps the high virtual alias.
                # Add an identity mapping to this temporary test image only.
                entry = (root / source).read_text(encoding="utf-8")
                marker = "    .zero 8 * 511"
                if entry.count(marker) != 1:
                    raise SystemExit("Startup table changed; review the test-only boot adaptation.")
                entry = entry.replace(marker, "    .zero 8 * 2\n"
                    "    .quad (0x80000 << 10) | 0xcf\n    .zero 8 * 508")
                compile_source = str(tmp / "entry-test.S")
                Path(compile_source).write_text(entry, encoding="utf-8")
            subprocess.run(["riscv64-unknown-elf-gcc", *flags, *define, "-c",
                            compile_source, "-o", str(obj)], cwd=root, check=True)
            objects.append(str(obj))
        elf, image = tmp / "kernel", tmp / "kernel.bin"
        subprocess.run(["riscv64-unknown-elf-ld", "-m", "elf64lriscv", "-nostdlib",
                        "--gc-sections", "-T", "tools/kernel.ld", "-o", str(elf),
                        *objects], cwd=root, check=True)
        subprocess.run(["riscv64-unknown-elf-objcopy", "-O", "binary", str(elf), str(image)], check=True)
        command = ["qemu-system-riscv64", "-machine", "virt", "-m", "128M",
                   "-smp", "1", "-nographic", "-bios", "default",
                   "-kernel", str(image)]
        if os.environ.get("SLUB_QEMU_TRACE"):
            command += ["-d", "in_asm", "-D", str(logs / "slub-qemu-trace.log")]
        try:
            result = subprocess.run(command, cwd=root, text=True, capture_output=True, timeout=30)
        except subprocess.TimeoutExpired as exc:
            output = (exc.stdout or b"") + (exc.stderr or b"")
            if isinstance(output, bytes):
                output = output.decode("utf-8", errors="replace")
            (logs / f"slub-qemu-{backend}.log").write_text(output, encoding="utf-8")
            raise SystemExit(output + "\nQEMU timed out without clean shutdown.")
        output = result.stdout + result.stderr
        (logs / f"slub-qemu-{backend}.log").write_text(output, encoding="utf-8")
        if (result.returncode != 0 or "PMM_QEMU_PASS" not in output
                or "SLUB_QEMU_PASS" not in output or "SLUB_QEMU_FAIL" in output):
            raise SystemExit(output or f"QEMU exited with {result.returncode}")
        print(next(line for line in output.splitlines() if "PMM_QEMU_PASS" in line))
        print(next(line for line in output.splitlines() if "SLUB_QEMU_PASS" in line))
print("Both isolated RISC-V SLUB kernels passed. Full lab kernel integration remains separate.")
# 2410691：独立 QEMU 测试运行脚本 修改部分 结束
