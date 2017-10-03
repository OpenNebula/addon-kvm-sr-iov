#!/bin/bash

# -------------------------------------------------------------------------- #
# Copyright 2015-2017, CSIR Centre for High Performance Computing                 #
# Author: David Macleod & Israel Tshililo                                    #
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
source $(dirname $0)/../kvmrc

mac_address=$1
vf_pos=$[$2 + 1]
port_pos=$2
HCA_DEV=$3
HCA_PORT=$4
mellanox_address=$5

## CHECK if the vf is a Connectx-4 device
mHCA_addr=`echo $mellanox_address | cut -c 6-`
vHCA_type=`lspci | grep "$mHCA_addr" | grep -o 'ConnectX-4'`


if [ "$vHCA_type" == "ConnectX-4" ]; then
## Programm the GUIDS and VF maps for the mlx5 driver

    if [ "$mac_address" == "clear_guid" ]; then
    # Clear the VF's Port GUID
        echo "Follow" > /sys/class/infiniband/mlx5_$HCA_DEV/device/sriov/$port_pos/policy

	# Get the value of the Port GUID to be cleared
	vf_mac=$(cat /sys/class/infiniband/mlx5_$HCA_DEV/device/sriov/$port_pos/port)
        strip_mac=`echo "$vf_mac" |  sed "s/://g" | tr '[:upper:]' '[:lower:]'`
        vf_guid="0x$strip_mac"
    
        ## Update opensm partitions table
        discard=`su - oneadmin -c "ssh $SM_HOST -t sudo $(dirname $0)/wr_sm_pkeys.sh $mac_address $vf_guid"`

    else
    #Program the GUID with the IP encoded MAC: using mlx5 driver
        echo "00:00:$mac_address" > /sys/class/infiniband/mlx5_$HCA_DEV/device/sriov/$port_pos/port
        echo "Follow" > /sys/class/infiniband/mlx5_$HCA_DEV/device/sriov/$port_pos/policy
    fi    
else
## Programm the GUIDS and VF maps for the mlx4 driver
    
    ## Get the guids and VF maps needed for the mlx4 driver
    guids=`ls /sys/class/infiniband/mlx4_$HCA_DEV/iov/$mellanox_address/ports/$HCA_PORT/gid_idx`
    primary_guid=`echo $guids | cut -d ' ' -f1`
    vf_map=`cat /sys/class/infiniband/mlx4_$HCA_DEV/iov/$mellanox_address/ports/$HCA_PORT/gid_idx/$primary_guid`
    
    if [ "$mac_address" == "clear_guid" ]; then
    #Clear the GUID so that it may be assigned to another VF
        echo "0xffffffffffffffff" > /sys/class/infiniband/mlx4_$HCA_DEV/iov/ports/$HCA_PORT/admin_guids/$vf_map
    else
    #Program the GUID with the IP encoded MAC: using mlx4 driver
        strip_mac=`echo "$mac_address" | sed "s/://g" | tr '[:upper:]' '[:lower:]'`
        guid="0x$strip_mac"
        echo "$guid" > /sys/class/infiniband/mlx4_$HCA_DEV/iov/ports/$HCA_PORT/admin_guids/$vf_map
    fi
fi    

exit 0
