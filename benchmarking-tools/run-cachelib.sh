#!/bin/bash

NVME_COMMAND=
NVME_DEVICE=
BLOCK_SIZE=
CACHELIB_DIR=
CACHELIB_BRANCH=
CACHEBENCH_RUN_CONFIG=
LOG_DIR=
NVME_PRECONDITIONING_RUNS=
SAMPLING_INTERVAL_SEC=
WAF_SCRIPT=
FDP_FEAT=
FILL_UTILIZATION=
#Allocates RUs 0..NUM_RU_HANDLES-1 to the namespace being created if FDP is enabled
NUM_RU_HANDLES=
NS_DEV_UTIL_PERCENT=

device_to_controller() {
    local var DEVICE=$1
    echo ${DEVICE%n*} # Get substring until and excluding last n
}

device_to_namespace() {
    local var DEVICE=$1
    echo ${DEVICE##*n} # Get substring from and excluding last n
}

device_size() {
    local var DEVICE=$1
    echo `$NVME_COMMAND id-ctrl $DEVICE | grep -i tnvmcap | awk '{print $3}' | sed 's/,//g'`
}

device_blocks() {
    local var DEVICE_SIZE=$(device_size $1)
    echo $(($DEVICE_SIZE / $BLOCK_SIZE))
}

ns_blocks() {
    local var DEVICE_SIZE=$(device_size $1)
    echo $(($NS_DEV_UTIL_PERCENT * $DEVICE_SIZE / (100 * $BLOCK_SIZE)))
}

## Returns the modified string with a single trailing character passed as argument
with_single_trailing_character() {
    local var DATA=$1
    local var APPEND_CHAR=$2
    ## Remove all occurences of the character from the end of string and append a single one
    echo ${DATA%%$APPEND_CHAR*}$APPEND_CHAR
}

is_fdp_enabled() {
    local var DEVICE=$1
    local var NVME_CONTROLLER=$(device_to_controller $NVME_DEVICE)
    local var FDPE_STATUS=`$NVME_COMMAND get-feature $NVME_CONTROLLER -f $FDP_FEAT -H | grep "(FDPE)" | awk -F ':' '{print $2}' | sed 's/ //g'`
    ## Check the FDPE_STATUS, deduced to be enabled if the status variable returns Yes
    [ "$FDPE_STATUS" = "Yes" ] && echo "1"
}

supports_fdp() {
    local var DEVICE=$1
    local var CTR_ATT=$(eval "expr `$NVME_COMMAND id-ctrl $DEVICE | grep -i ctratt | awk '{print $3}'`")
    ## Return the 19th bit of the hexadecimal value
    echo "$(((CTR_ATT >> 19) & 0x1))"
}

run_enable_fdp() {
    local var DEVICE=$(device_to_controller $NVME_DEVICE)
    local var FDP_ENABLED=$(supports_fdp $DEVICE)
    [ 1 -ne $FDP_ENABLED ] && echo "Drive does not support FDP since 19th bit of the value of the command 'nvme id-ctrl | grep ctratt' is not set according to specs" && exit 1
    $NVME_COMMAND set-feature $DEVICE -f $FDP_FEAT -c 1 -s
    $NVME_COMMAND get-feature $DEVICE -f $FDP_FEAT -H
}

run_disable_fdp() {
    local var DEVICE=$(device_to_controller $NVME_DEVICE)
    $NVME_COMMAND set-feature $DEVICE -f $FDP_FEAT -c 0 -s
    $NVME_COMMAND get-feature $DEVICE -f $FDP_FEAT -H
}

run_allocate() {
    local var NVME_CONTROLLER=$(device_to_controller $NVME_DEVICE)
    local var NAMESPACE_ID=$(device_to_namespace $NVME_DEVICE)
    local var NS_BLOCKS=$(ns_blocks $NVME_CONTROLLER)
    local var FDP_ENABLED=$(is_fdp_enabled $NVME_DEVICE)

    local var ALLOCATE_NS_COMMAND="$NVME_COMMAND create-ns -b $BLOCK_SIZE $NVME_CONTROLLER --nsze=$NS_BLOCKS --ncap=$NS_BLOCKS"

    if [ "$FDP_ENABLED" = "1" ]
    then
        local var RU_HANDLES=`seq -s ',' 0 $((NUM_RU_HANDLES-1))`
        ALLOCATE_NS_COMMAND+=" -p $RU_HANDLES -n $NUM_RU_HANDLES"
    fi

    echo "Running allocate namespace command: $ALLOCATE_NS_COMMAND"
    $ALLOCATE_NS_COMMAND
    ## Always attaches the first controller
    local var CONTROLLER=$(eval "expr `$NVME_COMMAND list-ctrl $NVME_CONTROLLER -c 0 | grep ':0x' | awk -F ':' '{print $2}'`")
    local var ATTACH_NS_COMMAND="$NVME_COMMAND attach-ns $NVME_CONTROLLER --namespace-id=$NAMESPACE_ID --controllers=$CONTROLLER"
    echo "Running attach namespace command: $ATTACH_NS_COMMAND"
    $ATTACH_NS_COMMAND
}

run_delete() {
    local var NVME_CONTROLLER=$(device_to_controller $NVME_DEVICE)
    local var NAMESPACE_ID=$(device_to_namespace $NVME_DEVICE)
    local var DELETE_COMMAND="$NVME_COMMAND delete-ns $NVME_CONTROLLER -n $NAMESPACE_ID"
    echo "Running delete namespace command: $DELETE_COMMAND"
    $DELETE_COMMAND
}

run_deallocate() {
    local var NVME_CONTROLLER=$(device_to_controller $NVME_DEVICE)
    local var NS_BLOCKS=$(ns_blocks $NVME_CONTROLLER)
    local var DEALLOCATE_CMD="$NVME_COMMAND dsm $NVME_DEVICE --ad -s 0 -b $NS_BLOCKS"
    echo "Running deallocate using command: $DEALLOCATE_CMD"
    $DEALLOCATE_CMD
}

run_preconditioning() {
    local var PRECONDITION_UTILIZATION=$(with_single_trailing_character $FILL_UTILIZATION "%")
    local var PRECONDITION_CMD="fio --filename=$NVME_DEVICE --size=$PRECONDITION_UTILIZATION -direct=1 -name Fill -rw=write -numjobs=1 --ioengine=io_uring --iodepth=64 --blocksize=128K"
    for run in $( seq 1 $NVME_PRECONDITIONING_RUNS)
    do
        echo "Running preconditioning run $run with command: $PRECONDITION_CMD"
        $PRECONDITION_CMD
    done
    echo "Preconditioning is running in a screen, remember to check for it and terminate it."
}

run_cachelib_build() {
    local var CACHELIB_BUILD_CMD="cd $CACHELIB_DIR && git checkout $CACHELIB_BRANCH && ./contrib/build.sh -d -j -v"
    echo "Building cachelib with branch $CACHELIB_BRANCH using $CACHELIB_BUILD_CMD"
    bash -c "$CACHELIB_BUILD_CMD"
}

run_workload() {
    ## Print $NVME_COMMAND device status for visibility while running command
    echo "sudo nvme list output follows"
    $NVME_COMMAND list

    mkdir -p $LOG_DIR

    ## Run vmstat
    local var VMSTAT_CMD="vmstat $SAMPLING_INTERVAL_SEC > $LOG_DIR/vmstat.log 2>&1"
    echo "Starting screen for vmstat sampling using $VMSTAT_CMD"
    screen -dm -S vmstat bash -c "$VMSTAT_CMD"

    ## Run WAF measurement script
    local var WAF_CMD="$WAF_SCRIPT -d $NVME_DEVICE -i $SAMPLING_INTERVAL_SEC > $LOG_DIR/waf-measurement.csv 2>&1"
    echo "Starting screen for waf measurement sampling using $WAF_CMD"
    screen -dm -S waf bash -c "$WAF_CMD"

    ## Run Cachebench
    CACHEBENCH_EXEC_CONFIG="${CACHELIB_DIR}/${CACHEBENCH_RUN_CONFIG}"
    local var CACHEBENCH_CMD="$CACHELIB_DIR/opt/cachelib/bin/cachebench --json_test_config=$CACHEBENCH_EXEC_CONFIG --progress=$SAMPLING_INTERVAL_SEC --progress_stats_file=$LOG_DIR/cachebench-progress.log > $LOG_DIR/cachebench-run.log 2>&1"
    echo "Starting screen to run cachebench using $CACHEBENCH_CMD"
    screen -dm -S cachebench bash -c "$CACHEBENCH_CMD"
    echo "Remember to check and kill all screens when you are done, this script is not responsible for terminating them."
}

## For now require the script to be run as root to simplify
## piping of credentials to screen sessions
if [ "$(id -u)" != "0" ]; then
    echo "Please execute this script as sudo" 1>&2
    exit 1
fi

help()
{
    echo "Script to run experiments with cachelib. Contains various helpers to configure namespace and FDP related configs."
    echo "Contains defaults for all switches being used. This can be overriden using the -f flag and for individual commands too."
    echo "Note that the flags are order sensitive and must be used in the correct order if multiple flags are combined."
    echo
    echo "Syntax: run-cachelib.sh [-f] [-i] [-d|e|o|h|a|t|p|b|r]"
    echo "Options:"
    echo "f <CONFIG FILE>        Configuration file to load variables from. The variables in the config
                                 file will override the default configurations in this script."
    echo "i <DEV>                NVMe device to be used."
    echo "d                      Deletes the NVME namespace."
    echo "e                      Enables FDP on the controller for the namspace."
    echo "o                      Disables FDP on the controller for the namespace."
    echo "a <PERCENT_SIZE>       Allocates the NVME namespace passed as argument with the configured size."
    echo "t <PERCENT_SIZE>       Deallocates the configured percentage of the blocks on the NVMe namespace."
    echo "p <PERCENT_SIZE>       Preconditions the device by sequentially filling the device with the fill
                                 percentage passed as argument (default 100%)"
    echo "b <BRANCH>             Builds cachelib with the configured branch."
    echo "r <LOG_DIR>            Runs the cachebench workload while generating vmstat and waf measurements
                                 with the specified device and log directory."
    echo "h                      Print this help."
}

while getopts ":hdeoatpbrf:i:" option; do
    ARG=${!#} #Retrieve the last argument
    case $option in
        f)
	    source ${OPTARG}
	    ;;
	i)
	    NVME_DEVICE=${OPTARG}
	    ;;
	a)
	    [ "$ARG" != "-a" ] && NS_DEV_UTIL_PERCENT=$ARG
	    run_allocate
	    exit
	    ;;
	d)
	    run_delete
	    exit
	    ;;
	e)
	    run_enable_fdp
	    exit
	    ;;
        o)
	    run_disable_fdp
            exit
	    ;;
	t)
	    [ "$ARG" != "-t" ] && NS_DEV_UTIL_PERCENT=$ARG
            run_deallocate
            exit
	    ;;
        p)
	    [ "$ARG" != "-p" ] && FILL_UTILIZATION=$ARG
	    run_preconditioning
            exit
	    ;;
        b)
	    [ "$ARG" != "-b" ] && CACHELIB_BRANCH=$ARG
            run_cachelib_build
            exit
	    ;;
        r)
	    [ "$ARG" != "-r" ] && LOG_DIR=$ARG
            run_workload
            exit
	    ;;
        h)
	    help
            exit
	    ;;
        \?)
	    echo "Error: Invalid option"
	    exit
	    ;;
    esac
done
