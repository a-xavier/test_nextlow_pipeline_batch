process SINGLE_FASTQ_ALIGNMENT {

    container 'debian:stable-slim'
    conda 'bioconda::bowtie2=2.5.5 bioconda::minimap2=2.30 bioconda::samtools=1.23  conda-forge::awscli'

    cpus 4
    memory 16.GB

    publishDir "${params.publishDir}/Aligned_BAMs", mode: 'copy', pattern: '*_aligned.bam'

    input:
    tuple path(fastq), path(preset_file), path(fastqc_zip_file)
    path reference_fasta_file // from channel in subworkflow, ensures it gets passed to AWS batch

    output:
    path "${fastq.baseName}_aligned.bam"

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
    ${reference_fasta_file} \
    $fastq | samtools view -bS - | samtools sort -o ${fastq.baseName}_aligned.bam
   """
}

