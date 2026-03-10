process FASTQC {
    
    container 'debian:stable-slim'
    conda 'bioconda::fastqc=0.12.1 conda-forge::awscli'

    cpus 4
    memory 8.GB

    publishDir "${params.publishDir}/FastQC_Reports", mode: 'copy', pattern: '*_fastqc.zip'

    input:
    path fastq

    output:
    tuple path(fastq), path("${fastq.baseName}_preset.txt"), path("${fastq.baseName}_fastqc.zip")
    
   

    script:
    """
    fastqc $fastq --outdir . --threads ${task.cpus} --extract

    # Read output - Get stats - Check if small or long reads - drop tag file and use either bowtie2 or minimap2 for alignment
    parse_fastqc_report.sh ./*_fastqc/fastqc_data.txt > ${fastq.baseName}_preset.txt

    """
}