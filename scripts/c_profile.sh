#!/bin/sh

################################################################################
#
# This script can be used to profile C execution. This script should be run with 
# "nohup" so that the profiling will continue even when the TTY session is 
# ended.
#
# In order to correctly compile the executables for profiling, the following 
# command should be used:
#     `make mode=debug gprof=on inline=force binary'
#
# Usage:
#     `nohup c_profile.sh DESCRIPTION >LOG_FILE'
#
################################################################################

#===============================================================================
# Configuration
#===============================================================================
ALGORITHM_DIR=../TopN_Outlier_Pruning_Block
BIN_EXT=bin
ROOT_OUTPUT_DIR=Profiling
DATA_DIR=../TopN_Outlier_Pruning_Block/data
DATA_EXT=dat
ITERATIONS=3
#===============================================================================

SCRIPT_DIR=$(readlink -f $(dirname $0))
ALGORITHM_DIR=$(readlink -f $SCRIPT_DIR/$ALGORITHM_DIR)
BIN_DIR=$(readlink -f $ALGORITHM_DIR/bin)
DATASET_DIR=$(readlink -f $SCRIPT_DIR/$DATA_DIR)

ALL_PROFILES="
    TopN_Outlier_Pruning_Block_NO_BLOCKING
    TopN_Outlier_Pruning_Block_SORTED
    TopN_Outlier_Pruning_Block_UNSORTED
"
ALL_DATASETS="
    testoutrank
    ball1
    testCD
    runningex1k
    testCDST2
    testCDST3
    testCDST
    runningex10k
    runningex20k
    segmentation
    runningex30k
    pendigits
    runningex40k
    spam_train
    runningex50k
    spam
    letter-recognition
    mesh_network
    magicgamma
    musk
    connect4
"

# Get profile description from command line
if [ $# -lt 1 ]; then
    DESCRIPTION=$(date '+%Y-%m-%d')
else
    DESCRIPTION="$1"
fi

# Output directory
OUTPUT_DIR=$ROOT_OUTPUT_DIR/$DESCRIPTION
if [ -e "$OUTPUT_DIR" ]; then
    echo "Directory already exists: $OUTPUT_DIR" >&2
    exit 1
else
    mkdir --parents $OUTPUT_DIR
fi

# Start profiling
for DATASET_NAME in $ALL_DATASETS; do
    DATASET_FILE=$DATASET_DIR/$DATASET_NAME.$DATA_EXT
    
    if [ ! -f "$DATASET_FILE" ]; then
        echo "Data set file not found: $DATASET_FILE" >&2
        exit 2
    fi
    
    for ITERATION in $(seq 1 $ITERATIONS); do
        for PROFILE_NAME in $ALL_PROFILES; do
            PROFILE_OUTPUT_DIR=$OUTPUT_DIR/$DATASET_NAME/$ITERATION/$PROFILE_NAME
            mkdir --parents $PROFILE_OUTPUT_DIR
            
            PROFILE_EXE=$BIN_DIR/$PROFILE_NAME.$BIN_EXT
            PROFILE_LOG=$PROFILE_OUTPUT_DIR/output.log
            
            if [ ! -f "$PROFILE_EXE" ]; then
                echo "Profile not found: $PROFILE_EXE" >&2
                exit 3
            elif [ ! -x $PROFILE_EXE ]; then
                echo "Profile not executable: $PROFILE_EXE" >&2
                exit 4
            fi
            
            # Output summary information
            echo ""
            echo "Date: $(date '+%d-%b-%Y %H:%M:%S')"
            echo "Data set: $DATASET_NAME"
            echo "Iteration: $ITERATION"
            echo "Profile: $PROFILE_NAME"
            echo "Output directory: $PROFILE_OUTPUT_DIR"
            
            # Execute the command
            $PROFILE_EXE $DATASET_FILE >> $PROFILE_LOG
            if [ $? -ne 0 ]; then
                echo "Executable returned non-zero value!" >&2
                exit 5
            fi
            
            # gprof files
            if [ ! -f gmon.out ]; then
                echo "Cannot find gmon.out!" >&2
                echo "Make sure that the '-pg' flags were used for compilation" >&2
                exit 6
            else
                gprof $PROFILE_EXE > $PROFILE_OUTPUT_DIR/gprof.txt
                gprof --line $PROFILE_EXE > $PROFILE_OUTPUT_DIR/gprof_line.txt
                gprof --brief $PROFILE_EXE > $PROFILE_OUTPUT_DIR/gprof_brief.txt
                mv gmon.out $PROFILE_OUTPUT_DIR/
            fi
        done
    done
done

echo ""
echo "Done"
