process FASTQC {
    publishDir "${params.publishDir}/FastQC_Reports", mode: 'copy', pattern: '*_fastqc.zip'

    input:
        val meta
        path fastq_uri


    output:
        path "*.zip" // Accept any zip, will match the correct one

    script:

    """
    fastqc "${fastq_uri}" --outdir . --threads ${task.cpus} --extract
    """
}