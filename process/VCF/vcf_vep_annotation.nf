process VEP_ANNOTATE {
    publishDir "${params.publishDir}/Annotated_VCFs", mode: 'copy'

    input:
      path vcf
      val vep_cache
      path fasta_reference
      path fasta_reference_index
      path fasta_reference_dict

    output:
      path "${vcf.baseName}_annotated.vcf"
      

    script:
    def isBatch = workflow.profile?.contains('awsbatch')
    """
   set -euo pipefail

echo "=== Runtime Environment ==="
echo "PWD: \$(pwd)"
echo "Task CPUs: ${task.cpus}"

# Define a local path for the cache within the current working directory
# Nextflow's 'scratch true' ensures this is on the 400GB disk
LOCAL_CACHE_DIR="\$(pwd)/vep_cache_local"

if [ "${isBatch}" = "true" ]; then
    echo "=== AWS Batch Mode: Initializing Local Cache ==="
    
    # 1. Create the directory
    mkdir -p "\$LOCAL_CACHE_DIR"

    # 2. Sync from S3 to the local 400GB disk
    # This is much faster than streaming over the network during annotation
    echo "Syncing VEP cache from S3: ${vep_cache}"
    aws s3 sync "${vep_cache}" "\$LOCAL_CACHE_DIR" --no-progress
    
    CACHE_DIR="\$LOCAL_CACHE_DIR"
else
    echo "=== Local/HPC Mode: Using Provided Path ==="
    CACHE_DIR="${vep_cache}"
fi

echo "=== Cache Verified ==="
ls -ld "\$CACHE_DIR"

# Run VEP
# Note: --fork should usually match task.cpus for maximum speed
vep \
    -i ${vcf} \
    --vcf \
    -o ${vcf.baseName}_annotated.vcf \
    --species homo_sapiens \
    --merged \
    --everything \
    --cache --offline \
    --dir_cache "\$CACHE_DIR" \
    --fork ${task.cpus} \
    --buffer_size 50000 \
    --fasta ${fasta_reference}

echo "=== Annotation Complete ==="
    """
}