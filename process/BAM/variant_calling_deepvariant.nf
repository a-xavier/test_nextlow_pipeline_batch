// this process will call variants from a bam file using DeepVariant. 

process VARIANT_CALLING_DEEPVARIANT {
    
    publishDir "${params.publishDir}/VCFs/Deepvariant", mode: 'copy'

    input:
        tuple val(sample_name), path(aligned_bam_file), path(aligned_bam_file_index)// No sample id because we are done with it by now
        path fasta_reference
        path fasta_index
        path fasta_dicta
    output:
        path "${aligned_bam_file.baseName}_variants.g.vcf.gz"
        path "${aligned_bam_file.baseName}_variants.vcf.gz"
        

    script:  // TODO: In this process -> do a check for preset (using bam instead of fastq) and also check if WGS WES or something else

    """
    # Read preset file
    # If map-ont -> ONT
    # if map-hifi -> PACBIO
    # if sr -> SHORTREAD

  /opt/deepvariant/bin/run_deepvariant \\
  --model_type=WGS \\
  --ref=${fasta_reference} \\
  --reads=${aligned_bam_file} \\
  --output_vcf=${aligned_bam_file.baseName}_variants.vcf.gz \\
  --output_gvcf=${aligned_bam_file.baseName}_variants.g.vcf.gz \\
  --num_shards=${task.cpus} \\
  --vcf_stats_report=true \\
  --disable_small_model=true \\
  --logging_dir=logs
    """

}