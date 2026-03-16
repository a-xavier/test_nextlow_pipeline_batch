process MERGE_BAM_BY_SAMPLE_NAME {
    container 'debian:stable-slim'
    conda 'bioconda::samtools=1.23 conda-forge::awscli'
    cpus 4
    memory 16.GB

    publishDir "${params.publishDir}/Merged_BAMs", mode: 'copy'

    input:
        tuple val(sample_name), path(bam_files), val(sample_id), val(file_unique_id)

    output:
        path "${sample_name}.bam"

    script:
    """
    echo "Merging BAM files for sample ${sample_name} with samtools merge"
    samtools merge -@ ${task.cpus} -o ${sample_name}.bam ${bam_files.join(' ')}
    """
}