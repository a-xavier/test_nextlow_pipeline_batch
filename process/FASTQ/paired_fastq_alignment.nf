process PAIRED_FASTQ_ALIGNMENT {

    publishDir "${params.publishDir}/Aligned_BAMs", mode: 'copy', pattern: '*_aligned_filtered.bam'

    input:
    tuple val(meta), path(fastq_uri_r1), path(fastq_uri_r2)
    path reference_mmi_file // from channel in subworkflow, ensures it gets passed to AWS batch

    output:
    tuple(
        val(meta.identity.sample_name),
        val(meta.identity),
        path("${meta.entity.key}_${meta.file.lane_id}_aligned_filtered.bam")
    )

    script:
    // Map platform to minimap2 preset
    def preset = 'sr'
    if (meta.entity.platform == 'SHORT_READS' || meta.entity.platform == 'UNKNOWN' || !meta.entity.platform) {
        preset = 'sr'
    } else if (meta.entity.platform == 'PACBIO') {
        preset = 'map-hifi'
    } else if (meta.entity.platform == 'ONT') {
        preset = 'map-ont'
    }

    // Read Groups 
    def ID = "${meta.entity.key}_${meta.file.lane_id}"
    def SM = "${meta.sample?.sample_name ?: meta.entity.key}"
    def LB = "${meta.entity.key}"
    def PL = "${meta.entity.platform ?: 'UNKNOWN'}"
    def PU = "${meta.file.lane_id}"

    def RG = "@RG\\tID:${ID}\\tSM:${SM}\\tLB:${LB}\\tPL:${PL}\\tPU:${PU}"


    """
    minimap2 \
    -a -x ${preset} \
    -R "${RG}" \
    ${reference_mmi_file} \
    ${fastq_uri_r1} ${fastq_uri_r2} | samtools view -bS - | samtools sort -o ${meta.entity.key}_${meta.file.lane_id}_aligned.bam
   
    # Here only keep the autosomes + X + Y + MT - Discard decoy contigs and unplaced contigs
    # This avoids downstream issues
    # If aligned by us then chromosomes are 1 2 3 4...X Y MT
    samtools index ${meta.entity.key}_${meta.file.lane_id}_aligned.bam
    samtools view -b ${meta.entity.key}_${meta.file.lane_id}_aligned.bam 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X Y MT > ${meta.entity.key}_${meta.file.lane_id}_aligned_filtered.bam
   """
}

