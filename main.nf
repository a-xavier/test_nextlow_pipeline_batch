nextflow.enable.dsl=2

// Import all subworkflows
include { vcf_subworkflow } from './subworkflows/vcf_subworkflow.nf'
include { single_fastq_subworkflow } from './subworkflows/single_fastq_subworkflow.nf'
// Processes 
include { ZIP_PUBLISHDIR } from './process/OTHER/zip_publishdir.nf'

workflow {
    main:
        // 0 - Get the analysis ID from the command line arguments
        if (!params.analysis_id) {
            error "Missing required parameter: --analysis_id"
        } else {
            println "Analysis ID: ${params.analysis_id}"
        }

        // 1 - Access the json on s3
        def s3_json_path = "s3://portalseq/Analysis/${params.analysis_id}/Inputs/${params.analysis_id}_run.json"
       // Assign to metadata channel - this will be used to pass metadata to
       def metadata_ch = channel
        .fromPath(s3_json_path)
        .map { path -> 
            return new groovy.json.JsonSlurper().parse(path) 
        }

        metadata_ch.view { meta ->
            println "########################"
            println "Analysis Name: ${meta.analysisName}"
            println "Analysis ID: ${meta.id}"
            println "Selected Options: ${meta.selectedOptions}"
            // print all validated inputs 
            // if usUrl print url otherwise print file.path 
            meta.validatedInputs.each { input ->
                def src = input.isUrl
                    ? input.url
                    : "${input.file.path}"
                
                println "${src}: ${input.classification}"
            }
            println "########################"
        }

        // 3 - Create a chanel for input files based on metadata 
        // Will handle URL and S3 files 
        metadata_ch
        .flatMap { meta -> 
        // We pass 'meta' into the next step so it's never null
        return meta.validatedInputs.collect { [meta, it] } 
        }
        .map { meta, input ->
            def src = input.isUrl
                ? input.url
                : "s3://portalseq/Analysis/${params.analysis_id}/Inputs/${input.file.path.replaceFirst('^\\./','')}"

            // Use the 'meta' we just confirmed exists
            def (sample_id, sample_name, group_name) = SampleSheetParser.parseSampleSheet(meta, file(src))

            return tuple(input.classification, file(src), sample_id, sample_name, group_name)
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
        def branches = input_files_ch.branch { item ->
            vcf: item[0] == 'VCF'
            bam_aligned_no_mod: item[0] == 'BAM/CRAM/SAM (aligned reads)'
            single_fastq: item[0] == 'Single FastQ'
            other: true
        }

    // Combine the branches 
    // this step prevents triggering a step if no vcf / fastq / pod5 etc as input
    // Combine the metadata channel with the corresponding file channels for each subworkflow so each 
    // Second item here is a file Path
    vcf_inputs_ch = metadata_ch.combine(branches.vcf.map { vcf_item -> vcf_item })
    fastq_inputs_ch = metadata_ch.combine(branches.single_fastq.map { fastq_item -> fastq_item })

    // Call the subworkflows
    // 2 cant trigger at same time for now
    def empty_ch = channel.empty()

    def tag_single_fq = single_fastq_subworkflow(fastq_inputs_ch).final_files_single_fastq
    
    def tag_vcf = vcf_subworkflow(vcf_inputs_ch).final_files_vcf
    
    def tag_channel = empty_ch.mix(
        tag_single_fq,
        tag_vcf
    ).collect()

    ZIP_PUBLISHDIR(
        tag_channel,
        metadata_ch.map { meta -> meta.analysisName }, // Assuming name_of_run is the same for all items, we can just take the first one 
        "${params.publishDir}"
    )
}