include { FASTQC } from '../process/FASTQ/fastqc.nf'
include { SINGLE_FASTQ_ALIGNMENT } from '../process/FASTQ/single_fastq_alignment.nf'


workflow single_fastq_subworkflow {
    
    take:

       combined_ch // This is a channel of tuples: [metadata, single_fastq_file]

    main:

        println "Running single FASTQ subworkflow"
        combined_ch.view { "Input FASTQ file: ${it[1]}" }

        // Create file input for all custom scripts in /bin otherwise they do not get passed to AWS batch 
        def fastqc_report_parser_ch = channel.value(file("${projectDir}/bin/parse_fastqc_report.sh"))

        fastq_and_preset_ch = FASTQC( combined_ch.map { tuple -> tuple[1]}, fastqc_report_parser_ch  )
        
        fastq_and_preset_ch.view { output -> "FASTQC output: ${output}" }

        SINGLE_FASTQ_ALIGNMENT(fastq_and_preset_ch)
}

