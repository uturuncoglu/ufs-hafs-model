#!/bin/bash
set -eux

source rt_utils.sh
source atparse.bash

mkdir -p ${RUNDIR}
cd $RUNDIR

###############################################################################
# Make configure and run files
###############################################################################

# FV3 executable:
cp ${PATHRT}/$FV3X                                 fv3.exe

# modulefile for FV3 prerequisites:
cp ${PATHRT}/modules.fv3_${COMPILE_NR}             modules.fv3

# Get the shell file that loads the "module" command and purges modules:
cp ${PATHRT}/../NEMS/src/conf/module-setup.sh.inc  module-setup.sh

SRCD="${PATHTR}"
RUND="${RUNDIR}"

atparse < ${PATHRT}/hycom_conf/${HYCOM_RUN:-hycom_run.IN} > hycom_run

# Set up the run directory
source ./hycom_run

if [[ $SCHEDULER = 'pbs' ]]; then
  NODES=$(( TASKS / TPN ))
  if (( NODES * TPN < TASKS )); then
    NODES=$(( NODES + 1 ))
  fi
  atparse < $PATHRT/fv3_conf/fv3_qsub.IN > job_card
elif [[ $SCHEDULER = 'slurm' ]]; then
  NODES=$(( TASKS / TPN ))
  if (( NODES * TPN < TASKS )); then
    NODES=$(( NODES + 1 ))
  fi
  atparse < $PATHRT/fv3_conf/fv3_slurm.IN > job_card
elif [[ $SCHEDULER = 'lsf' ]]; then
  if (( TASKS < TPN )); then
    TPN=${TASKS}
  fi
  NODES=$(( TASKS / TPN ))
  if (( NODES * TPN < TASKS )); then
    NODES=$(( NODES + 1 ))
  fi
  atparse < $PATHRT/fv3_conf/fv3_bsub.IN > job_card
fi

# Driver
atparse < ${PATHTR}/parm/${NEMS_CONFIGURE:-nems.configure} > nems.configure
atparse < ${PATHTR}/parm/${MODEL_CONFIGURE:-model_configure.cdeps.IN} > model_configure

# CMEPS
cp ${PATHTR}/parm/fd.yaml fd.yaml
cp ${PATHTR}/parm/pio_in pio_in
cp ${PATHTR}/parm/med_modelio.nml med_modelio.nml

# CDEPS
cp ${PATHTR}/parm/atm_modelio.nml atm_modelio.nml
atparse < ${PATHTR}/parm/${DATM_CONFIGURE_A:-datm_in} > datm_in
atparse < ${PATHTR}/parm/${DATM_CONFIGURE_B:-datm.streams.xml} > datm.streams.xml

# HYCOM
atparse < ${PATHTR}/parm/${HYCOM_CONFIGURE_A:-blkdat.input} > blkdat.input
atparse < ${PATHTR}/parm/${HYCOM_CONFIGURE_B:-patch.input} > patch.input
atparse < ${PATHTR}/parm/${HYCOM_CONFIGURE_C:-ports.input} > ports.input
atparse < ${PATHTR}/parm/${HYCOM_CONFIGURE_D:-hycom_settings} > hycom_settings
atparse < ${PATHTR}/parm/${HYCOM_CONFIGURE_E:-limits} > limits

################################################################################
# Submit test
################################################################################

if [[ $ROCOTO = 'false' ]]; then
  submit_and_wait job_card
else
  chmod u+x job_card
  ./job_card
fi

check_results

################################################################################
# End test
################################################################################

exit 0
