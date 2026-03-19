process VEP_ANNOTATE {
    publishDir "${params.publishDir}/Annotated_VCFs", mode: 'copy'

    input:
      path vcf
      val vep_cache // this is a folder or a s3 path that contains the VEP cache / pass a value because we will have different use for it
      path fasta_reference 
      path fasta_reference_index
      path fasta_reference_dict


    output:
      path "${vcf.baseName}_annotated.vcf"
    

    script:
    
    def isBatch = params.profile_name == "awsbatch"
    """
    # If on aws download cache from s3, otherwise use local cache
    
    if ${isBatch}; then
      mkdir -p vep_cache
      aws s3 sync ${vep_cache} vep_cache --no-progress
      CACHE_DIR=vep_cache
    else
        CACHE_DIR=${vep_cache}
    fi


    vep \
      -i ${vcf} \
      --vcf \
      -o ${vcf.baseName}_annotated.vcf \
      --species homo_sapiens \
      --merged \
      --everything \
      --cache --offline \
      --dir_cache \$CACHE_DIR \
      --fork ${task.cpus} \
      --buffer_size 50000 \
      --fasta ${fasta_reference}
    """
}