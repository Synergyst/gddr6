#!/bin/bash

get_pci_info() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <device_id>"
    return 1
  fi
  local device_id="0000:$1"
  local device_dir="/sys/bus/pci/devices/$device_id"
  if [ ! -d "$device_dir" ]; then
    echo "Device $device_id not found"
    return 1
  fi
  declare -A gen_map
  gen_map["2.5 GT/s"]="1.x"
  gen_map["5.0 GT/s"]="2.x"
  gen_map["8.0 GT/s"]="3.x"
  gen_map["16.0 GT/s"]="4.0"
  gen_map["32.0 GT/s"]="5.0"
  gen_map["64.0 GT/s"]="6.0"
  gen_map["128.0 GT/s"]="7.0"
  local link_speed_file="$device_dir/current_link_speed"
  local link_width_file="$device_dir/current_link_width"
  if [ -f "$link_speed_file" ] && [ -f "$link_width_file" ]; then
    local link_speed=$(cat "$link_speed_file" | awk '{print $1 " " $2}')
    local link_width=$(cat "$link_width_file")
    local generation=${gen_map["$link_speed"]}
    echo "Current PCI-e generation: $generation ($link_speed), $link_width-lanes"
  else
    echo "Unable to retrieve link speed and width for device $device_id"
    return 1
  fi
}

get_pci_vram_temps() {
#  if [ "$#" -ne 2 ]; then
#    echo "Usage: $0 <device_id> <offset>"
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <device_id>"
    return 1
  fi
  base_address=0x$(lspci -vs 0000:$1|grep 'Memory at '|awk '{print $3}'|head -n1)
  #memory_offset=0x$2
  memory_offset=0x9a44b0
  result=$(printf "0x%X" "$((base_address + memory_offset))")
  vidmemaddr=$(busybox devmem $result|grep -v '0x00000000')
  if [[ -z $vidmemaddr ]]; then
    continue
  fi
  vidmemtemp=$((($vidmemaddr >> 5) & 0x3FF))
  echo "$vidmemtemp°C"
}

read_dev_table() {
  local table=("${!1}")
  local key="$2"
  for element in "${table[@]}"; do
    value=$(echo "$element" | grep -oP "$key=\K[^ ]+")
    echo "$value"
  done
}

declare -A dev_table
dev_table[0]="offset=0000E2A8 dev_id=2684 vram='GDDR6X' arch='AD102' name='RTX-4090'"
dev_table[1]="offset=0000E2A8 dev_id=2704 vram='GDDR6X' arch='AD103' name='RTX-4080'"
dev_table[2]="offset=0000E2A8 dev_id=2782 vram='GDDR6X' arch='AD104' name='RTX-4070-Ti'"
dev_table[3]="offset=0000E2A8 dev_id=2786 vram='GDDR6X' arch='AD104' name='RTX-4070'"
dev_table[4]="offset=0000E2A8 dev_id=2204 vram='GDDR6X' arch='GA102' name='RTX-3090'"
dev_table[5]="offset=0000E2A8 dev_id=2203 vram='GDDR6X' arch='GA102' name='RTX-3090-Ti'"
dev_table[6]="offset=0000E2A8 dev_id=2208 vram='GDDR6X' arch='GA102' name='RTX-3080-Ti'"
dev_table[7]="offset=0000E2A8 dev_id=2206 vram='GDDR6X' arch='GA102' name='RTX-3080'"
dev_table[8]="offset=0000E2A8 dev_id=2216 vram='GDDR6X' arch='GA102' name='RTX-3080-LHR'"
dev_table[9]="offset=0000EE50 dev_id=2484 vram='GDDR6' arch='GA104' name='RTX-3070'"
dev_table[10]="offset=0000EE50 dev_id=2488 vram='GDDR6' arch='GA104' name='RTX-3070-LHR'"
dev_table[11]="offset=0000E2A8 dev_id=2531 vram='GDDR6' arch='GA106' name='RTX-A2000'"
dev_table[12]="offset=0000E2A8 dev_id=2571 vram='GDDR6' arch='GA106' name='RTX-A2000'"
dev_ids=$(read_dev_table "dev_table[@]" "dev_id")
product_ids=$(read_dev_table "dev_table[@]" "dev_id")
offset_vals=$(read_dev_table "dev_table[@]" "offset")
#card_names=$(read_dev_table "dev_table[@]" "name")

value_in_array() {
  local value="$1"
  local array=("${!2}")
  for item in "${array[@]}"; do
    if [ "$item" == "$value" ]; then
      return 0 # found
    fi
  done
  return 1 # not found
}

#while true; do
  # COMMENT THE IPMI SECTION HERE AND SEE THE END OF THIS SCRIPT IF YOU ARE NOT RUNNING ON A SYSTEM WITH IPMI
  #systempinfo=$((ipmitool sensor|grep 'degrees C'|grep -v 'na         | degrees C') & )
  dmoninfo=$((nvidia-smi dmon -s pcmt -c 1) & )
  #dmoninfo=$((nvidia-smi dmon -s pucvmet -c 1) & )
  capacity=0
  carditer=0
  card_count=0
  vram_values=()
  while read -r m; do
    vram_values+=("$m")
    capacity=$(($capacity + $m))
    card_count=$(($card_count + 1))
  done < <(nvidia-smi | grep MiB | grep '%' | cut -f3 -d'/' | awk '{print $1}' | cut -f1 -d'M')
  product_id_values=()
  while read -r m; do
    product_id_values+=("$m")
  done < <(lspci -nn|grep ' \[10de\:'|grep 'VGA compatible controller'|sed 's/.*\[10de\://'|cut -f1 -d']')
  cards=()
  while read -r m; do
    cards+=("$m")
  done < <(nvidia-smi|grep '| 00000000:'|grep 'NVIDIA'|grep 'On  \|'|sed 's/On  .*//'|sed 's/.*NVIDIA GeForce //')
  core_temps=()
  while read -r m; do
    core_temps+=("$m")
  done < <(nvidia-smi|grep '%'|cut -f2 -d'%'|awk '{print $1}'|cut -f1 -d'C')
  offset_values=()
  while read -r m; do
    offset_values+=("$m")
  done < <(for m in $offset_vals ; do echo $m ; done)
  for m in $(lspci -vvv|sed -n '/VGA compatible controller/,/Kernel modules: nvidiafb/p'|grep 'VGA compatible controller'|awk '{print $1}') ; do
    echo -en "[$carditer] ${cards[$carditer]} (10de:${product_id_values[$carditer]} / 0000:$m)"
    echo -en "\n\t$(get_pci_info $m)"
    echo -en "\n\tVRAM capacity: ${vram_values[$carditer]} MiB"
    echo -en "\n\tCore temp: ${core_temps[$carditer]}°C"
    vram_check_iter=0
    for k in $product_ids ; do
      if [ "${product_id_values[$carditer]}" == "$k" ] ; then
        echo -en "\n\tVRAM temp: $(get_pci_vram_temps $m)"
        break
      fi
      vram_check_iter=$(($vram_check_iter + 1))
    done
    echo
    carditer=$(($carditer + 1))
  done
  #echo -e "\nTotal VRAM capacity: $capacity MiB\n\n$dmoninfo\n\n$systempinfo\n\n----------------------------------------------\n"
  # Comment above, then uncomment below if using a system without IPMI
  echo -e "\nTotal VRAM capacity: $capacity MiB\n\n$dmoninfo\n\n----------------------------------------------\n"
#  sleep 90
#done
