process MERGE_BAM_BY_SAMPLE_NAME {
    
    publishDir "${params.publishDir}/Merged_BAMs", mode: 'copy'

    input:
        tuple val(sample_name), path(bam_files), val(sample_id)

    output:
        tuple val(sample_name), path("${sample_name}.bam")

    script:
    """
    echo "Merging BAM files for sample ${sample_name} with samtools merge"
    samtools merge -@ ${task.cpus} -o ${sample_name}.bam ${bam_files.join(' ')}
    """
}