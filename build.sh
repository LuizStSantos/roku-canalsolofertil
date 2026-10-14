#!/usr/bin/env bash
# Gera out/canalsolofertil.zip com o manifest na raiz (formato aceito pelo instalador da Roku)
set -e
cd "$(dirname "$0")"
mkdir -p out
rm -f out/canalsolofertil.zip
zip -r out/canalsolofertil.zip manifest source components images -x "*.DS_Store"
echo "Pronto: out/canalsolofertil.zip"
