#!/bin/sh

set -xe

mkdir -p out/
fasm2 src/splc.asm out/splc
./out/splc ./example.spl
