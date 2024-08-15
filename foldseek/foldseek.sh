#!/bin/bash

# Assign input/ouput variables
pdb_files_paths=Alphafold/alphafold_structures/
results_tsv_path=foldseek/foldseek_results.tsv
aln_tsv_path=foldseek/foldseek_aln_results.tsv

# create temporary directory to store foldseek files
TMP_DIR=$(mktemp -d)

# Subdirectories where the databases will be stored
STRUC_DB_DIR="$TMP_DIR/strucDB/"
ALN_DB_DIR="$TMP_DIR/alignmentDB/"
TMP_DIR="$TMP_DIR/tmp/"
# Ensure the subdirectories exists
mkdir -p "$STRUC_DB_DIR"
mkdir -p "$ALN_DB_DIR"
mkdir -p "$TMP_DIR"
# Define the database paths
STRUC_DB="$STRUC_DB_DIR/strucDB"
ALN_DB="$ALN_DB_DIR/alignmentDB"

# Create database for the target
foldseek createdb \
    $pdb_files_paths $STRUC_DB \
    -v 1

# Run foldseek search
foldseek search \
    $STRUC_DB $STRUC_DB $ALN_DB $TMP_DIR \
    -a \
    --alignment-type 2 \
    --exhaustive-search 1 \
    -v 1

# Convert the results to tsv files
foldseek convertalis \
    $STRUC_DB $STRUC_DB $ALN_DB $results_tsv_path \
    --format-mode 4 \
    --format-output "query,target,alntmscore,prob,rmsd,pident,evalue,bits,u,t,lddt,lddtfull" \
    -v 1

# Convert the alignment to tsv files
foldseek convertalis \
    $STRUC_DB $STRUC_DB $ALN_DB $aln_tsv_path\
    --format-mode 4 \
    --format-output "query,target,cigar,qstart,qend,qlen,tstart,tend,tlen,alnlen" \
    -v 1

# Remove temporary directory
rm -r "$TMP_DIR"