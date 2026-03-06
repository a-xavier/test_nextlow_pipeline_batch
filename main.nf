// Import all subworkflows
include { vcf_subworkflow } from './subworkflows/vcf_subworkflow.nf'

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

            tuple(input.classification, file(src))
        }
            .set { input_files_ch }
        
        // 4 - Dispatch processes based on classification
        // input_files_ch = looks like a collection of [VCF, /davetang/vcf_example/raw/refs/heads/main/vcf/S1.haplotypecaller.filtered.phased.vcf.gz]
        // All files have same classification so grabe the first one and use it to decide which process to call

        // For each classification we pipe it to the proper subworkflow
            def branches = input_files_ch.branch {
                vcf:    { tuple -> tuple[0] == 'VCF' }
                bam:    { tuple -> tuple[0] == 'BAM' }
                fastq:  { tuple -> tuple[0] == 'FASTQ' }
                other:  { tuple -> true }
            }

        vcf_ch   = branches.vcf
        bam_ch   = branches.bam
        fastq_ch = branches.fastq
        other_ch = branches.other

        // Call proper workflow for each classification
        vcf_subworkflow(metadata_ch, vcf_ch.map {   tuple -> tuple[1] })

}
