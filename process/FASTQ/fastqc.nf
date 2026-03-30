process FASTQC {
    publishDir "${params.publishDir}/FastQC_Reports", mode: 'copy', pattern: '*_fastqc.zip'

    input:
        tuple val(metadata), val(file_classification), path(fastq), val(sample_id), val(sample_name), val(group_name)
        path parser_script // from /bin to ensure it gets passed to AWS batch


    output:
        tuple val(sample_id), path(fastq), path("*_preset.txt")
        path "*.zip" // Accept any zip, will match the correct one

    script:

    // Do root name here 
    def root_name = fastq.getBaseName().replaceAll(/\.fastq(\.gz)?$/, '').replaceAll(/\.fq(\.gz)?$/, '')

    """
    fastqc "$fastq" --outdir . --threads ${task.cpus} --extract

    # Read output - Get stats - Check if small or long reads - drop tag file and use either bowtie2 or minimap2 for alignment

    # Try absolute path
    ${parser_script} ./${root_name}_fastqc/fastqc_data.txt > ${root_name}_preset.txt
    """
}

// HEre using baseName does not work it file is .fastq.gz because fastqc renames the output to 
// example_3_fastqc.zip instead of example_3.fastq_fastqc.zip
// we need to just handle cases of .fastq and .fastq.gz as well as fq and fq.gz