#!/bin/bash

# -------------------------------------------------------------------------- #
# Copyright 2016-2017, CSIR Centre for High Performance Computing                 #
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

address=$1
HCA_DEV=$2
HCA_PORT=$3
fileNum=$4
fileVal=$5
Pkey_id="Pkey$6"   ## Pkey ID as value in the /etc/partitions.conf
mac_add=$7


## CHECK if the vf is a Connectx-4 device
mHCA_addr=`echo $address | cut -c 6-`
vHCA_type=`lspci | grep "$mHCA_addr" | grep -o 'ConnectX-4'`


if [ "$vHCA_type" == "ConnectX-4" ]; then
## Programm the GUIDS and VF maps for the mlx5 driver

    # Get the GUID value
    vf_mac=$(cat /dev/shm/vf_interfaces/ib0/* | grep `echo $mac_add | cut -d ':' -f 3-6`)
    strip_mac=`echo "$vf_mac" |  sed "s/://g" | tr '[:upper:]' '[:lower:]'`
    vf_guid="0x0000$strip_mac"

    # Update opensm partitions table
    discard=`su - oneadmin -c "ssh $SM_HOST -t sudo $(dirname $0)/wr_sm_pkeys.sh $Pkey_id $vf_guid"`
else
## Programm the GUIDS and VF maps for the mlx4 driver
    echo $fileVal > "/sys/class/infiniband/mlx4_$HCA_DEV/iov/$address/ports/$HCA_PORT/pkey_idx/$fileNum"

fi

exit 0
