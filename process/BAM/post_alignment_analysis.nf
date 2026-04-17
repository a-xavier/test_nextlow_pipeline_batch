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
    tuple val(sample_name), val(identity), path(aligned_bam_file)
    path fasta_reference
    path fasta_reference_index
    path fasta_reference_dict
    path common_variant_vcf
    path common_variant_vcf_index

    output:
        tuple val(sample_name), val(identity), path("${aligned_bam_file.baseName}_analysis_ready.bam")
        path "${aligned_bam_file.baseName}_duplication_metrics.txt"

    script:
    """
   # Script will
   # 1 Do BQSR -> Apply BQSR 
   # 2 Mark duplicates

    # 1 - BQSR
    gatk BaseRecalibrator \\
    -I ${aligned_bam_file} \\
    -R ${fasta_reference.name} \\
    --known-sites ${common_variant_vcf} \\
    -O ${aligned_bam_file.baseName}_recal_data.table \\
    --maximum-cycle-value 50000

    # 2 - Apply BQSR 
    gatk ApplyBQSR \\
    -R ${fasta_reference.name} \\
    -I ${aligned_bam_file} \\
    --bqsr-recal-file ${aligned_bam_file.baseName}_recal_data.table \\
    -O ${aligned_bam_file.baseName}_bqsr.bam

    # TODO DEDUPLICATE BASED ON UMI TOO later
    # 3 - Mark Duplicates (based on location)
    gatk MarkDuplicates \\
    -I ${aligned_bam_file.baseName}_bqsr.bam \\
    -O ${aligned_bam_file.baseName}_analysis_ready.bam \\
    -M ${aligned_bam_file.baseName}_duplication_metrics.txt

    # 4 - Index the final bam file
    # Will create a bai file with the same name as the bam file but with .bai extension
    samtools index ${aligned_bam_file.baseName}_analysis_ready.bam 
 
    """

    
}