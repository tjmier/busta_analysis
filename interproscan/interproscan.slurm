#!/bin/bash
#SBATCH --job-name=interproscan  # Job name
#SBATCH --output=output_%j.txt      # Output file name (%j expands to jobID)
#SBATCH --error=error_%j.txt        # Error file name (%j expands to jobID)
#SBATCH --ntasks=1                  # Run a single task
#SBATCH --cpus-per-task=20          # Request 20 CPU cores
#SBATCH --mem=8G                    # Request 8GB of memory
#SBATCH --time=00:30:00             # Time limit (hh:mm:ss)
#SBATCH --partition=batch         # Partition to submit to (adjust based on your system)
#SBATCH --nodes=1                   # Ensure the job runs on a single node
 
PROJECT_DIR=/work/cahoonlab/tjmier/interproscan
FILE_DIR=$PROJECT_DIR/p450_edit.fasta
OUTPUT_DIR=$PROJECT_DIR/interproscan_p450.tsv

module load java/11
module load interproscan/5.63

interproscan.sh -i $FILE_DIR -o $OUTPUT_DIR -f tsv