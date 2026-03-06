process VCF_STATS {
    container 'debian:stable-slim'
    conda 'bioconda::bcftools=1.23 conda-forge::awscli'
    cpus 1
    memory '2 GB'
    
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