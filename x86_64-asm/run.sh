#!/bin/sh

set -xe

mkdir -p out/
fasm2 src/splc.asm out/splc
./out/splc ./test.spl

# fasm2 src/test.asm out/test
# ./out/test 
