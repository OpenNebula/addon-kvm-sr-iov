#!/bin/bash

# -------------------------------------------------------------------------- #
# Copyright 2013, CSIR Centre for High Performance Computing                 #
# Author: David Macleod                                                      #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

HCA_PORT=1

vlan_id=$1
deploy_id=$2
vf_pos=$3
vf_pos=$[vf_pos + 1]

#Extract bus slot and function addresses
bus=`virsh -c qemu:///system dumpxml $deploy_id | grep "<hostdev" -A 3 | grep "address" | cut -d "'" -f4 | sed "$vf_pos q;d" | cut -d "x" -f2`
slot=`virsh -c qemu:///system dumpxml $deploy_id | grep "<hostdev" -A 3 | grep "address" | cut -d "'" -f6 | sed "$vf_pos q;d" | cut -d "x" -f2`
function=`virsh -c qemu:///system dumpxml $deploy_id | grep "<hostdev" -A 3 | grep "address" | cut -d "'" -f8 | sed "$vf_pos q;d" | cut -c 3`
#Build vf address
address="0000:$bus:$slot.$function"

if [ "$vlan_id" == "no_vlan" ]; then
  #If no VLAN is specified map the pkey to the hosts default
  echo 0 > "/sys/class/infiniband/mlx4_0/iov/$address/ports/$HCA_PORT/pkey_idx/0"
  echo none > "/sys/class/infiniband/mlx4_0/iov/$address/ports/$HCA_PORT/pkey_idx/1"
else
  #If a VLAN is specified calculate its equivalent pkey
  
  #Convert to binary
  pkey_bin=`echo "obase=2;$vlan_id" | bc`
  pkey_len=`echo $pkey_bin | wc -m`

  #Check if the pkey has full memebership
  if [ $pkey_len -gt 15 ]; then
    #If the pkey has full membership no correction is applied and the key is converted to hex
    pkey_full=`printf '%x\n' "$((2#$pkey_bin))"`
    pkey_part=$pkey_full
  else
    #If the pkey is not specifed with full membership then generate the pkey with full membership
    pkey_diff=$[16 - pkey_len]
    position=0
    pkey_full=1
    while [ $position -lt $pkey_diff ] 
    do
      position=$[$position + 1]
      pkey_full="${pkey_full}0"
    done
    #Convert the binary pkey to hex
    pkey_full_hex=`printf '%x\n' "$((2#$pkey_full$pkey_bin))"`
    pkey_part_hex=`printf '%x\n' "$((2#$pkey_bin))"`
    #Add 0s to the hex pkeys to correct if necassary
    pkey_part_hex_len=`echo $pkey_part_hex | wc -m`
    if ! [ $pkey_part_hex_len -eq 5 ]; then
      pkey_hex_diff=$[5 - pkey_part_hex_len]
      position=0
      while [ $position -lt $pkey_hex_diff ]
      do
        position=$[$position + 1]
        pkey_part_hex_fix="0$pkey_part_hex_fix"
      done
    fi
    pkey_full="$pkey_full_hex"
    pkey_part="$pkey_part_hex_fix$pkey_part_hex"
  fi
  #Add 0x to the pkeys to make them compatible with format the IB system stores them in
  pkey_full="0x"$pkey_full
  pkey_part="0x"$pkey_part
  #Find all the pkeys allocated to the system and search for a match
  num_files=`ls /sys/class/infiniband/mlx4_0/ports/1/pkeys/ | wc -l`
  key_found=0
  position=0
  while [ $position -lt $num_files ]
  do
    pkey=`cat /sys/class/infiniband/mlx4_0/ports/1/pkeys/$position`
    #If a match is found stop searching and record its position for mapping
    if [ "$pkey" == "$pkey_full" ] || [ "$pkey" == "$pkey_part" ]; then
      map_pos=$position
      position=$num_files
      key_found=1
    fi
    position=$[$position + 1]
  done 
  if [ $key_found -eq 1 ]; then
    #If a pkey match was found apply the vf map
    echo 0 > "/sys/class/infiniband/mlx4_0/iov/$address/ports/$HCA_PORT/pkey_idx/1"
    echo $map_pos > "/sys/class/infiniband/mlx4_0/iov/$address/ports/$HCA_PORT/pkey_idx/0"
  else
    #If the requested pkey was not found block the VM's IB port
    echo none > "/sys/class/infiniband/mlx4_0/iov/$address/ports/$HCA_PORT/pkey_idx/1"
    echo none > "/sys/class/infiniband/mlx4_0/iov/$address/ports/$HCA_PORT/pkey_idx/0"
  fi
fi

exit 0
