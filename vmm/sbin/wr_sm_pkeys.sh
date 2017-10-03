#!/bin/bash

# -------------------------------------------------------------------------- #
# Copyright 2016-2017, CSIR Centre for High Performance Computing                 #
# Author: Israel Tshililo & David Macleod                                    #
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
Pkey_id=$1
GUID=$2

## Partitions files
tmp_parts=/etc/opensm/partitions.conf.tmp
conf_pkeys=/etc/opensm/partitions.conf

LCK=/dev/shm/partitions_lock
exec 200>$LCK
flock -x 200

## Check for GUID && Pkey in the partitions.conf
sm_guid=$(cat $conf_pkeys | grep "$GUID")
sm_pkey=$(cat $conf_pkeys | grep "$Pkey_id")

if [ -z "$sm_guid" ]; then
  ## If the GUID is not found in partitions tables

    if [ "$Pkey_id" == "clear_guid" ]; then
      # No action required here if GUID is empty
        discard=$(echo -e "No GUID to be cleared\n")

    elif [ "$Pkey_id" == "Pkeyno_vlan" ]; then
      # If no specific Pkey given, no action required either. Opensm will used the Default 
        discard=$(echo -e "VF using Default Pkey")

        ## Update the opensm to recognise the changes
        discard=` pkill -HUP opensm`
    else
     # Write the GUID to the partitions.conf
	discard=`sed "/$Pkey_id/ s/;//g; /$Pkey_id/ s/ALL=full//g; /$Pkey_id/s/$/, $GUID=full;/g; /$Pkey_id/ s/  / /g; /$Pkey_id/ s/: ,/: /g;  " 	 $conf_pkeys > $tmp_parts`
	discard=`mv -f $tmp_parts $conf_pkeys`

	## Update the SM to recognise the changes
	discard=` pkill -HUP opensm`
    fi
else
  ## If GUID is found in the partitions.conf 

    # Check if the GUID needs to be deleted
    if [ "$Pkey_id" == "clear_guid" ]; then
	## Delete the GUID from the partitions.conf
	discard=`sed "/$GUID/ s/, $GUID=full//g;" $conf_pkeys > $tmp_parts`
	discard=`mv -f $tmp_parts $conf_pkeys`

	## Update the SM to recognise the changes
	discard=` pkill -HUP opensm`
    else
	## GUID already assigned
        discard=$(echo -e "GUID already assigned\n")
    fi
fi

exit 0
