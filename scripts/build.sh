#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for lab in lab1 lab2 lab3; do
  mkdir -p ".build/$lab"
  ghc -O2 -Wall -threaded -rtsopts "-i$lab/src" "$lab/app/Main.hs" -outputdir ".build/$lab" -o ".build/$lab-run"
done
mkdir -p .build/tests
ghc -O2 -Wall -threaded -rtsopts -ilab1/src -ilab2/src -ilab3/src tests/Main.hs -outputdir .build/tests -o .build/test-run
.build/test-run +RTS -N4 -RTS
