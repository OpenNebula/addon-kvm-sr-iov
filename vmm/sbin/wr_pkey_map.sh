#!/bin/bash

# -------------------------------------------------------------------------- #
# Copyright 2016, CSIR Centre for High Performance Computing                 #
# Author: David Macleod, Israel Tshililo                                     #
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

address=$1
HCA_DEV=$2
HCA_PORT=$3
fileNum=$4
fileVal=$5

echo $fileVal > "/sys/class/infiniband/mlx4_$HCA_DEV/iov/$address/ports/$HCA_PORT/pkey_idx/$fileNum"
exit 0
