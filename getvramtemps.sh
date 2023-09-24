#!/bin/bash

# Usage: ./getvramtemps.sh <PCI slot ID>
# ie: ./getvramtemps.sh 22:00.0
for m in $(lspci -vs 0000:$1|grep 'Memory at '|awk '{print $3}'|head -n1) ; do
  base_address=0x$m
  memory_offset=0x9a44b0
  result=$(printf "0x%X" "$((base_address + memory_offset))")
  vidmemaddr=$(busybox devmem $result|grep -v '0x00000000')
  if [[ -z $vidmemaddr ]]; then
    continue
  fi
  vidmemtemp=$((($vidmemaddr >> 5) & 0x3FF))
  echo "$vidmemtemp°C"
done
