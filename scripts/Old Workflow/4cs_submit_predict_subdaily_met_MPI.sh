#!/bin/sh
#$ -wd /projectnb/dietzelab/paleon/met_ensemble/scripts/
#$ -j y
#$ -S /bin/bash
#$ -V
#$ -m e
#$ -q "geo*"
#$ -pe omp 12
#$ -M crollinson@gmail.com
#$ -l h_rt=120:00:00
#$ -N diel_MPI
#cd /projectnb/dietzelab/paleon/met_ensemble/scripts/

R CMD BATCH 4c_predict_subdaily_met_MPI.R
