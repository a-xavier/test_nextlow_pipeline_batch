include { FASTQC } from '../process/FASTQ/fastqc.nf'
include { SINGLE_FASTQ_ALIGNMENT } from '../process/FASTQ/single_fastq_alignment.nf'


workflow single_fastq_subworkflow {
    
    take:

       combined_ch // This is a channel of tuples: [metadata, single_fastq_file]

    main:

        println "Running single FASTQ subworkflow"
        combined_ch.view { "Input FASTQ file: ${it[1]}" }

        fastq_and_preset_ch = FASTQC( combined_ch.map { tuple -> tuple[1] } )

        fastq_and_preset_ch.view { "FASTQC output: ${it}" }

        SINGLE_FASTQ_ALIGNMENT(fastq_and_preset_ch)
}

