#!/bin/bash

for m in `lspci -v|grep -A10 VGA|grep -A10 NVIDIA|egrep -v 'Subsystem:|Flags: |I/O ports at |Expansion ROM at |Capabilities: '|grep -A1 'VGA compatible controller: '|grep 'Memory at '|awk '{print $3}'` ; do
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
