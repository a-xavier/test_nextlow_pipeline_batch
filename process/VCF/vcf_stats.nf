process VCF_STATS {
    
    // We tell Nextflow to send the result to S3
    publishDir params.publishDir, mode: 'copy'
    
    // Logic: Input VCF File and Output a stats file using bcftools
    input: path input_vcf
    output: path "${input_vcf.baseName}_stats.txt"
    script:
    """
    bcftools stats $input_vcf > ${input_vcf.baseName}_stats.txt
    """
}