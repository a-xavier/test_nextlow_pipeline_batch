process POST_ALIGNMENT_ANALYSIS {
    
    container 'debian:stable-slim'
    conda 'bioconda::gatk4=4.6.2.0 conda-forge::awscli'
    cpus 4
    memory 16.GB

    publishDir "${params.publishDir}/Post_Alignment_Analysis", mode: 'copy'

    // Input need: THe bam file / the preset file (for PL Read Group) / the sample name channel (fro SM and ID Read Groups)
    input:
    val metadata
    path aligned_bam_file // from previous step in subworkflow
    path preset_file
    tuple val(sample_id), val(sample_name) 
    // Reference files
    path fasta_reference 
    path common_variant_vcf
    path fasta_index
    path fasta_dict
    path common_variant_index

    output:
    path "${aligned_bam_file.baseName}_analysis_ready.bam"
    path "${aligned_bam_file.baseName}_duplication_metrics.txt"

    script:
    """

    echo "Work dir contents before linking:"
    ls -lh


   # Script will
   # 0 add Reads Group automatically based on metadata and bam file name
   # 1 Do BQSR -> Apply BQSR 
   # 2 Mark duplicates

   # Read preset file 
   # If map-ont -> ONT 
   # if map-hifi -> PACBIO
   # if sr -> SHORTREAD

    PLATFORM=\$(cat ${preset_file} )
    echo "Platform for read group is \$PLATFORM "

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