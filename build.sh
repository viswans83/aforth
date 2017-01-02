#!/usr/bin/env bash

case $1 in
    osx)
        NASMFLAGS="-fmacho32 -DOSX"
        LDFFAGS=""
        ;;
    linux)
        NASMFLAGS="-felf32"
        LDFLAGS="-m elf_i386"
        ;;
    *)
        echo 'usage: ./build.sh [osx|linux]'
        exit 1
esac

rm -f aforth && nasm $NASMFLAGS -o aforth.o aforth.S && ld $LDFLAGS -o aforth aforth.o && echo 'aforth build OK' && exit 0

echo 'aforth build FAILED'
exit 1
