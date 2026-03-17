process SINGLE_FASTQ_ALIGNMENT {

    publishDir "${params.publishDir}/Aligned_BAMs", mode: 'copy', pattern: '*_aligned.bam'

    input:
    tuple val(sample_id), path(fastq), path(preset_file)
    path reference_mmi_file // from channel in subworkflow, ensures it gets passed to AWS batch

    output:
    tuple val(sample_id), path("${fastq.baseName}_aligned.bam")

    script:
    """
    # Check tag file content preset_file for preset
    preset=\$(cat ${preset_file})

    # If preset is different to sr / map-ont / map-hifi then exit with error 
    if [[ "\$preset" != "sr" && "\$preset" != "map-ont" && "\$preset" != "map-hifi" ]]; then
        echo "Error: Invalid preset '\$preset'. Expected 'sr', 'map-ont', or 'map-hifi'."
        exit 1
    fi

    minimap2 \
    -a -x \$preset \
    ${reference_mmi_file} \
    $fastq | samtools view -bS - | samtools sort -o ${fastq.baseName}_aligned.bam
   """
}

