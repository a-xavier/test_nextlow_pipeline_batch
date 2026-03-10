process SINGLE_FASTQ_ALIGNMENT {

    container 'debian:stable-slim'
    conda 'bioconda::bowtie2=2.5.5 bioconda::minimap2=2.30 bioconda::samtools=1.23  conda-forge::awscli'

    cpus 4
    memory 16.GB

    publishDir "${params.publishDir}/Aligned_BAMs", mode: 'copy', pattern: '*_aligned.bam'

    input:
    tuple path(fastq), path(preset_file), path(fastqc_zip_file)

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


   echo "Testing mount access..."
    ls -ld ${params.reference_dir}

    minimap2 \
    -a -x \$preset \
    ${params.reference_dir}/Reference_Genomes/Human/GRCh38/Homo_sapiens.GRCh38.dna_sm.toplevel.fa \
    $fastq | samtools view -bS - | samtools sort -o ${fastq.baseName}_aligned.bam
   """
}