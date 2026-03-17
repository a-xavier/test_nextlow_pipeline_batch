nextflow.enable.dsl=2

// Import all subworkflows
include { vcf_subworkflow } from './subworkflows/vcf_subworkflow.nf'
include { single_fastq_subworkflow } from './subworkflows/single_fastq_subworkflow.nf'

workflow {
    main:
        // 0 - Get the analysis ID from the command line arguments
        if (!params.analysis_id) {
            error "Missing required parameter: --analysis_id"
        } else {
            println "Analysis ID: ${params.analysis_id}"
        }

        // 1 - Access the json on s3
        def jsonFile = file("s3://portalseq/Analysis/${params.analysis_id}/Inputs/${params.analysis_id}_run.json")
        def metadata = new groovy.json.JsonSlurper().parse(jsonFile)

        // 2 - Create channel from metadata
        channel.value(metadata).set { metadata_ch }

        // 3 - Create a chanel for input files based on metadata 
        // Will handle URL and S3 files 
        metadata_ch
        .map { meta -> meta.validatedInputs }
        .flatten()
        .map { input ->
            def src = input.isUrl
                ? input.url
                : "s3://portalseq/Analysis/${params.analysis_id}/Inputs/${input.file.path.replaceFirst('^\\./','')}"

            def (sample_id, sample_name, group_name) = SampleSheetParser.parseSampleSheet(metadata, file(src))

            // Pass only the fields you want (no unique_file_id)
            tuple(input.classification, file(src), sample_id, sample_name, group_name)
        }
        .set { input_files_ch }
        // 4 - Dispatch processes based on classification
        // input_files_ch = looks like a collection of [VCF, /davetang/vcf_example/raw/refs/heads/main/vcf/S1.haplotypecaller.filtered.phased.vcf.gz]
        // All files have same classification so grabe the first one and use it to decide which process to call

        // For each classification we pipe it to the proper subworkflow
        // "Paired-end FastQ",
        // "Single FastQ",
        // "BAM/CRAM/SAM (unaligned reads)",
        // "BAM/CRAM/SAM (aligned reads)",
        // "BAM/CRAM/SAM (unaligned with methylation)",
        // "BAM/CRAM/SAM (aligned with methylation)",
        // "Fast5 (Nanopore)",
        // "Pod5 (Nanopore)",
        // "VCF"
        def branches = input_files_ch.branch {
            vcf: it[0] == 'VCF'
            bam_aligned_no_mod: it[0] == 'BAM/CRAM/SAM (aligned reads)'
            single_fastq: it[0] == 'Single FastQ'
            other: true
        }

    // Combine the branches 
    // this step prevents triggering a step if no vcf / fastq / pod5 etc as input
    // Combine the metadata channel with the corresponding file channels for each subworkflow so each 
    // Second item here is a file Path
    vcf_inputs_ch = metadata_ch.combine(branches.vcf.map { vcf_item -> vcf_item })
    fastq_inputs_ch = metadata_ch.combine(branches.single_fastq.map { fastq_item -> fastq_item })

    // Call the subworkflows
    vcf_subworkflow(vcf_inputs_ch)
    single_fastq_subworkflow(fastq_inputs_ch)

}