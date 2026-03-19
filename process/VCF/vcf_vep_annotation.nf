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

    echo "=== Runtime checks ==="
    echo "PWD=\$(pwd)"
    echo "workflow.profile=${workflow.profile}"
    echo "isBatch=${isBatch}"
    echo "vep_cache=${vep_cache}"

    if ${isBatch}; then
        CACHE_BASE=/scratch/vep_cache
        LOCK_FILE=/scratch/vep_cache.lock
        COMPLETE_FLAG=\$CACHE_BASE/.complete
        TMPDIR=/scratch/tmp

        echo "=== Checking /scratch mount ==="
        if ! mountpoint -q /scratch; then
            echo "ERROR: /scratch is not mounted"
            exit 1
        fi

        df -h /scratch
        mkdir -p /scratch "\$TMPDIR"

        (
            flock -x 9

            if [ ! -f "\$COMPLETE_FLAG" ]; then
                echo "Populating VEP cache into \$CACHE_BASE"
                rm -rf "\$CACHE_BASE"
                mkdir -p "\$CACHE_BASE"

                aws s3 sync "${vep_cache}" "\$CACHE_BASE" --no-progress

                touch "\$COMPLETE_FLAG"
            else
                echo "VEP cache already present on this instance"
            fi
        ) 9>"\$LOCK_FILE"

        CACHE_DIR="\$CACHE_BASE"
    else
        CACHE_DIR="${vep_cache}"
    fi

    echo "=== Cache location ==="
    echo "CACHE_DIR=\$CACHE_DIR"
    ls -ld "\$CACHE_DIR" || true
    find "\$CACHE_DIR" -maxdepth 2 | head -50 || true

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
    """
}