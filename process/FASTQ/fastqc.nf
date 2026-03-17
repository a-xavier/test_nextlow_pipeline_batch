process FASTQC {
    publishDir "${params.publishDir}/FastQC_Reports", mode: 'copy', pattern: '*_fastqc.zip'

    input:
        tuple val(metadata), val(file_classification), path(fastq), val(sample_id), val(sample_name), val(group_name)
        path parser_script // from /bin to ensure it gets passed to AWS batch

    output:
        tuple val(sample_id), path(fastq), path("${fastq.baseName}_preset.txt")
        path "${fastq.baseName}_fastqc.zip" // fastq zip file not used further

    script:
    """
    fastqc $fastq --outdir . --threads ${task.cpus} --extract

    # Read output - Get stats - Check if small or long reads - drop tag file and use either bowtie2 or minimap2 for alignment
    
    # Try absolute path
    ${parser_script} ./*_fastqc/fastqc_data.txt > ${fastq.baseName}_preset.txt
    """
}