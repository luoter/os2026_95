#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
gcc -std=gnu99 -Wall -Wextra -Werror -O1 -g -fsanitize=address,undefined \
  -fno-builtin -Ilibs -Ikern/debug -Ikern/mm -Ikern/arch \
  tests/buddy_slub_host.c kern/mm/buddy_pmm.c kern/mm/slub.c kern/mm/slub_check.c \
  -o /tmp/lab2-buddy-slub-host
/tmp/lab2-buddy-slub-host
