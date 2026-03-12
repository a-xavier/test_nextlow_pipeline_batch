// Processes
include { FASTQC } from '../process/FASTQ/fastqc.nf'
include { SINGLE_FASTQ_ALIGNMENT } from '../process/FASTQ/single_fastq_alignment.nf'
include { POST_ALIGNMENT_ANALYSIS } from '../process/BAM/post_alignment_analysis.nf'

workflow single_fastq_subworkflow {
    
    take:

       combined_ch // This is a channel of tuples: [metadata, single_fastq_file]

    main:

        println "Running single FASTQ subworkflow"
        combined_ch.view { "Input FASTQ file: ${it[1]}" }

        // Create Channel for references
        // FASTA Reference
        def alignment_reference_fasta_file_ch = channel.fromPath("${params.reference_dir}/Reference_Genomes/Human/GRCh38/Homo_sapiens.GRCh38.dna_sm.toplevel.mmi")


        // Create file input for all custom scripts in /bin otherwise they do not get passed to AWS batch 
        def fastqc_report_parser_ch = channel.value(file("${projectDir}/bin/parse_fastqc_report.sh"))
        
        sample_name_ch = combined_ch.map { tuple -> SampleSheetParser.parseSampleSheet(tuple[0], tuple[1]) }

        // Step 1 - FASTQC
        fastq_and_preset_ch = FASTQC( combined_ch.map { tuple -> tuple[1]}, fastqc_report_parser_ch  )
        
        // Step 2 - Alignment With minimap
        aligned_bam_ch = SINGLE_FASTQ_ALIGNMENT(fastq_and_preset_ch, alignment_reference_fasta_file_ch)

        // Step 3 - GATK Post Alignment stuff
        // Arguments are metadata aligned bam - 3rd item of fastq_and_preset_ch (the preset file) and 
        POST_ALIGNMENT_ANALYSIS(
            combined_ch.map {it -> it [0]}, // metadata
            aligned_bam_ch, // aligned bam from previous step
            fastq_and_preset_ch.map { it -> it[1] }, // the preset file from the fastq step
            sample_name_ch) // sample id and sample name for read group

        // Collect all POST_ALIGNMENT_ANALYSIS bam files and then merge them if necessary based on the sample sheet 
        

}

