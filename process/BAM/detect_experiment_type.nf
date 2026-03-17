// Detect Experiment type based on the BAM coverage
// usibg megadepth and bedtools 
// if multi billion base covered -> Genome -> no bed
// Then compare bed to an exome bed -> if > 80% covered -> Exome -> Emit bed
// Else targeted   -> Emit bed

process DETECT_EXPERIMENT_TYPE {
    container 'debian:stable-slim'
    conda 'bioconda::megadepth=1.0.4 bioconda::bedtools=2.30.0 conda-forge::awscli'
    cpus 4
    memory 16.GB

    input:
    tuple val(sample_name), path(analysis_ready_bam_file)

    output:
    tuple val(sample_name), path("${analysis_ready_bam_file.baseName}_experiment_type.txt")

    script:
    """
    echo "Detecting experiment type for sample ${sample_name} using BAM file ${analysis_ready_bam_file}"

    """
    
}