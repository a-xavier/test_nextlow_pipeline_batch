process POST_ALIGNMENT_ANALYSIS {
    publishDir "${params.publishDir}/Post_Alignment_Analysis", mode: 'copy'

    // Input need: THe bam file / the preset file (for PL Read Group) / the sample name channel (fro SM and ID Read Groups)
    input:
    //  combined_ch.view { tuple -> 
    // def metadata = tuple [0]
    // def file_unique_id = tuple [1]
    // def file_classification = tuple [2]
    // def file_path = tuple [3]
    // def sample_id = tuple [4]
    // def sample_name = tuple [5]
    // def group_name = tuple [6]

    // This is combined channel
    tuple val(sample_id), val(metadata), val(file_classification), val(file_path), \
          val(sample_name), val(group_name), path(aligned_bam_file), path(preset_file)
    path fasta_reference
    path fasta_reference_index
    path fasta_reference_dict
    path common_variant_vcf
    path common_variant_vcf_index

    output:
        tuple val(sample_name), path("${aligned_bam_file.baseName}_analysis_ready.bam"), val(sample_id)
        path "${aligned_bam_file.baseName}_duplication_metrics.txt"

    script:
    """
   # Script will
   # 0 add Reads Group automatically based on metadata and bam file name
   # 1 Do BQSR -> Apply BQSR 
   # 2 Mark duplicates

   # Read preset file 
   # If map-ont -> ONT 
   # if map-hifi -> PACBIO
   # if sr -> SHORTREAD

    PLATFORM=\$(cat ${preset_file} )

   # 0 - Read groups 
   gatk AddOrReplaceReadGroups \\
    -I ${aligned_bam_file} \\
    -O ${aligned_bam_file.baseName}_rg.bam \\
    --RGLB ${metadata.id} \\
    --RGPL \$PLATFORM \\
    --RGPU ${metadata.id} \\
    --RGID  ${sample_id} \\
    --RGSM  ${sample_name}

    # 1 - BQSR
    gatk BaseRecalibrator \\
    -I ${aligned_bam_file.baseName}_rg.bam \\
    -R ${fasta_reference.name} \\
    --known-sites ${common_variant_vcf} \\
    -O ${aligned_bam_file.baseName}_recal_data.table \\
    --maximum-cycle-value 50000

    # 2 - Apply BQSR 
    gatk ApplyBQSR \\
    -R ${fasta_reference.name} \\
    -I ${aligned_bam_file.baseName}_rg.bam \\
    --bqsr-recal-file ${aligned_bam_file.baseName}_recal_data.table \\
    -O ${aligned_bam_file.baseName}_bqsr.bam

    # TODO DEDUPLICATE BASED ON UMI TOO later
    # 3 - Mark Duplicates (based on location)
    gatk MarkDuplicates \\
    -I ${aligned_bam_file.baseName}_bqsr.bam \\
    -O ${aligned_bam_file.baseName}_analysis_ready.bam \\
    -M ${aligned_bam_file.baseName}_duplication_metrics.txt
 
    """

    
}