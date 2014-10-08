#include <stdio.h>

// XXX: Trying to fix this directly in libelf results in *very* weird behaviour.

void _elf_seterr(int, int);

void _SHIM_elf_seterr(int x) {
	_elf_seterr(0, x);
}