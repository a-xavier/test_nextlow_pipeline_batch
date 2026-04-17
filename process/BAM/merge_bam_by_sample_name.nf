process MERGE_BAM_BY_SAMPLE_NAME {
    
    publishDir "${params.publishDir}/Merged_BAMs", mode: 'copy'

    input:
        // here we need path instead of val for list of files
        tuple val(sample_name), val(identities_list), path(bam_file_list)

    output:
        tuple val(sample_name), val(identities_list), path("${sample_name}.bam")

    script:
    """
    echo "Merging BAM files for sample ${sample_name} with samtools merge"
    samtools merge -@ ${task.cpus} -o ${sample_name}.bam ${bam_file_list.join(' ')}
    samtools index ${sample_name}.bam
    """
}