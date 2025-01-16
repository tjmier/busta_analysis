#!/bin/bash

fasta_path="sequences/p450_flat.fasta"
results_tsv_path="mmseqs/mmseqs_results.tsv"

# create temporary directory to store mmseq files
TMP_DIR=$(mktemp -d)

# Subdirectories where the databases will be stored
SEQ_DB_DIR="$TMP_DIR/seqDB/"
ALN_DB_DIR="$TMP_DIR/alignmentDB/"
TMP_DIR="$TMP_DIR/tmp/"
# Ensure the subdirectories exists
mkdir -p "$SEQ_DB_DIR"
mkdir -p "$ALN_DB_DIR"
mkdir -p "$TMP_DIR"
# Define the database paths
SEQ_DB="$SEQ_DB_DIR/seqDB"
ALN_DB="$ALN_DB_DIR/alignmentDB"

# Create database for the target
mmseqs createdb \
    $fasta_path $SEQ_DB \
    -v 1

# Run mmseqs search
mmseqs search \
    $SEQ_DB $SEQ_DB $ALN_DB $TMP_DIR \
    -s 7.5 \
    --max-seqs 10000 \
    -e 1 \
    --exhaustive-search 1 \
    -v 1

# Convert the results to tsv files
mmseqs convertalis \
    $SEQ_DB $SEQ_DB $ALN_DB $results_tsv_path \
    --format-mode 4 \
    --format-output "query,target,qlen,tlen,bits,evalue" \
    -v 1


# Remove temporary directory
rm -r "$TMP_DIR"