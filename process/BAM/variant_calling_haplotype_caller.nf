// this process will call variants from a bam file using GATK HaplotypeCaller 
// Let's Generate gvcf for each sample and then do joint genotyping in another step after collecting all of them 

process VARIANT_CALLING_HAPLOTYPE_CALLER {
    
    publishDir "${params.publishDir}/VCFs/GATK/" ,mode: 'copy'

    input:
        tuple val(sample_name), path(aligned_bam_file), path(aligned_bam_file_index)// No sample id because we are done with it by now
        path fasta_reference
        path fasta_index
        path fasta_dict
        path bed_coverage_maker_script
    output:
        path "${aligned_bam_file.baseName}_variants.g.vcf.gz"
        path "${aligned_bam_file.baseName}_variants.vcf.gz"

    script:  // TODO: In this process -> do a check for preset (using bam instead of fastq) and also check if WGS WES or something else

    """

    # Outfile pattern is OUTBED="\${BASENAME%.*}.bed"
    ./${bed_coverage_maker_script} 5 ${aligned_bam_file}

    gatk HaplotypeCaller \\
        -R ${fasta_reference} \\
        -I ${aligned_bam_file} \\
        -L ${aligned_bam_file.baseName}.bed \\
        -O ${aligned_bam_file.baseName}_variants.g.vcf.gz \\
        -ERC GVCF \\
        --native-pair-hmm-threads ${task.cpus}

    # Do Single sample genotyping to get a regular vcf as well
    gatk GenotypeGVCFs \\
        -R ${fasta_reference} \\
        -L ${aligned_bam_file.baseName}.bed \\
        -V ${aligned_bam_file.baseName}_variants.g.vcf.gz \\
        -O ${aligned_bam_file.baseName}_variants.vcf.gz
    """
}