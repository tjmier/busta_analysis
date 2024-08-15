#!/bin/bash

# This script is used to submit multiple Alphafold jobs in parallel using Slurm.
# Alphafold 2.3.2 monomer model is used for predicting protein structures.
# The reduced databases paramter is used for the template search to speed up the process.

# Only files within this block need to be edited
# ==========================================================================

# This is the directory where all of your files will be written to.
PROJECT_DIR=/lustre/work/cahoonlab/tjmier/alphafold/redo

# Directory containing the individual fasta files
FASTA_DIR=$PROJECT_DIR/missing_seqs

# Number of sequences to process in each batch
# Total number of jobs = number of sequences / batch size (rounded up)
batch_size=2

# Time limit for each batch job (hh:mm:ss)
# It takes about 1-1.5hrs to process one sequence (Highly dependent on seq length)
time_per_batch=03:00:00

# ==========================================================================

# Directory for output files
OUTPUT_BASE_DIR=$PROJECT_DIR/batch_output

# Base directory for Slurm files
SLURM_DIR=$PROJECT_DIR/slurm

# Directory to store Slurm job files
JOB_DIR=$SLURM_DIR/job_scripts

# Directory to store Slurm error files
ERROR_DIR=$SLURM_DIR/slurm_errors

# Directory to store Slurm output files
OUTPUT_DIR=$SLURM_DIR/slurm_outputs

# Directory to store best structures
TARGET_DIR=$PROJECT_DIR/best_structures

# Create the necessary directories if they don't exist
mkdir -p $SLURM_DIR $JOB_DIR $ERROR_DIR $OUTPUT_DIR $TARGET_DIR

# Collect all fasta files in an array
fasta_files=($FASTA_DIR/*.fasta)

# Create batches of fasta files
num_files=${#fasta_files[@]}
num_batches=$(( (num_files + batch_size - 1) / batch_size ))

# Array to hold job IDs
job_ids=()

# Loop through each batch
for ((i=0; i<num_batches; i++)); do
    # Get the current batch of fasta files
    batch=("${fasta_files[@]:i*batch_size:batch_size}")
    
    # Create a comma-separated list of fasta file paths
    fasta_paths=$(IFS=,; echo "${batch[*]}")
    
    # Create a base name for the job (using the first file in the batch)
    base_name=batch_$((i+1))
    
    # Define the output directory for this batch
    output_dir=$OUTPUT_BASE_DIR/output_$base_name

    # Create the output directory if it doesn't exist
    mkdir -p $output_dir
    
    # Create the Slurm job script for this batch of fasta files
    cat <<EOT > $JOB_DIR/$base_name.slurm
#!/bin/bash
#SBATCH --job-name=${base_name}_AlphaFold
#SBATCH --time=$time_per_batch         # Run time in hh:mm:ss
#SBATCH --mem-per-cpu=64000      # Maximum memory required per CPU (in megabytes)
#SBATCH --partition=gpu 
#SBATCH --gres=gpu:1
#SBATCH --constraint='gpu_32gb&gpu_v100'
#SBATCH --error=$ERROR_DIR/${base_name}.err
#SBATCH --output=$OUTPUT_DIR/${base_name}.out

module purge
module load apptainer

echo "Running Alphafold for batch $((i+1))..."
apptainer run -B /work/HCC/BCRF/app_specific/alphafold/2.3.2/:/data -B .:/etc \
    --pwd /app/alphafold docker://unlhcc/alphafold:2.3.2 \
    --fasta_paths=$fasta_paths \
    --output_dir=$output_dir \
    --model_preset=monomer \
    --db_preset=reduced_dbs \
    --use_gpu_relax \
    --max_template_date=2023-10-10 \
    --data_dir=/data \
    --small_bfd_database_path=/data/small_bfd/bfd-first_non_consensus_sequences.fasta \
    --mgnify_database_path=/data/mgnify/mgy_clusters_2022_05.fa \
    --pdb70_database_path=/data/pdb70/pdb70 \
    --template_mmcif_dir=/data/pdb_mmcif/mmcif_files \
    --uniref90_database_path=/data/uniref90/uniref90.fasta \
    --obsolete_pdbs_path=/data/pdb_mmcif/obsolete.dat \

echo "Alphafold for batch $((i+1)) completed."
EOT

    # Submit the generated job script and capture the job ID
    job_id=$(sbatch $JOB_DIR/$base_name.slurm | awk '{print $4}')
    job_ids+=($job_id)
done

# Create the post-processing script
cat <<EOT > $SLURM_DIR/post_process.sh
#!/bin/bash

# Directory where all your files are
PROJECT_DIR=$PROJECT_DIR

# Base output directory
OUTPUT_BASE_DIR=$OUTPUT_BASE_DIR

# Directory to store renamed files
TARGET_DIR=$TARGET_DIR

# Create the target directory if it doesn't exist
mkdir -p \$TARGET_DIR

# Find all ranked_0.pdb files at depth 3
find \$OUTPUT_BASE_DIR -maxdepth 3 -type f -name "ranked_0.pdb" | while read -r file; do
  # Get the parent directory name
  parent_dir=\$(basename "\$(dirname "\$file")")

  # Define the new filename
  new_filename="\${parent_dir}.pdb"

  # Copy and rename the file to the target directory
  cp "\$file" "\$TARGET_DIR/\$new_filename"
done

echo "Post-processing completed."
EOT

# Make the post-processing script executable
chmod +x $SLURM_DIR/post_process.sh

# Create a dependency string for the post-processing job
dependency=$(IFS=:; echo "${job_ids[*]}")

# Submit the post-processing job with dependency on all batch jobs
sbatch --dependency=afterok:$dependency $SLURM_DIR/post_process.sh
