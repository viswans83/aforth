#!/usr/bin/env bash

if [[ -z `which nasm` ]]; then
    echo 'aforth build FAILED: nasm not installed'
    exit 1
fi

case $1 in
    osx)
        NASMFLAGS="-fmacho32 -DOSX"
        LDFFAGS=""
        ;;
    bsd)
	NASMFLAGS="-felf32 -DBSD"
	LDFLAGS="-m elf_i386_fbsd"
	;; 
    linux)
        NASMFLAGS="-felf32 -Dlinux"
        LDFLAGS="-m elf_i386"
        ;;
    *)
        echo 'usage: ./build.sh [osx|bsd|linux]'
        exit 1
esac

rm -f aforth && \
    nasm $NASMFLAGS -o aforth.o aforth.S && \
    ld $LDFLAGS -o aforth aforth.o && \
    echo 'aforth build OK' && \
    exit 0

echo 'aforth build FAILED'
exit 1
