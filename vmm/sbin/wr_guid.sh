#!/bin/bash

# -------------------------------------------------------------------------- #
# Copyright 2015, CSIR Centre for High Performance Computing                 #
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

mac_address=$1
vf_pos=$[$2 + 1]
HCA_DEV=$3
HCA_PORT=$4
mellanox_address=$5

guids=`ls /sys/class/infiniband/mlx4_$HCA_DEV/iov/$mellanox_address/ports/$HCA_PORT/gid_idx`
primary_guid=`echo $guids | cut -d ' ' -f1`
vf_map=`cat /sys/class/infiniband/mlx4_$HCA_DEV/iov/$mellanox_address/ports/$HCA_PORT/gid_idx/$primary_guid`

if [ "$mac_address" == "clear_guid" ]; then
#Clear the GUID so that it may be assigned to another VF
  echo "0xffffffffffffffff" > /sys/class/infiniband/mlx4_$HCA_DEV/iov/ports/$HCA_PORT/admin_guids/$vf_map
else
#Program the GUID with the IP encoded MAC
  strip_mac=`echo "$mac_address" | sed "s/://g" | tr '[:upper:]' '[:lower:]'`
  guid="0x$strip_mac"
  echo "$guid" > /sys/class/infiniband/mlx4_$HCA_DEV/iov/ports/$HCA_PORT/admin_guids/$vf_map
fi

exit 0
