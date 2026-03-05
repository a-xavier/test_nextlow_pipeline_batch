process STEP_ONE {
    container 'debian:stable-slim'
    cpus 1
    memory '2 GB' // Adjusted to 2GB to match Fargate's 1-CPU requirement
    output: path 'test.txt'

    script:
    """
    touch test.txt
    """
}

process STEP_TWO {
    container 'debian:stable-slim'
    cpus 1
    memory '2 GB'
    
    // We tell Nextflow to send the result to S3
    publishDir params.publishDir, mode: 'copy'
    
    // Logic: Receive the file 'x' (test.txt), modify it, and output it again
    input: path x
    output: path x

    script:
    """
    echo "Hello World" > $x
    """
}

process VCF_STATS {
    container 'debian:stable-slim'
    conda 'bioconda::bcftools=1.23 conda-forge::awscli'
    cpus 1
    memory '2 GB'
    
    // We tell Nextflow to send the result to S3
    publishDir params.publishDir, mode: 'copy'
    
    // Logic: Input VCF File and Output a stats file using bcftools
    input: path input_vcf
    output: path "${input_vcf.baseName}_stats.txt"
    script:
    """
    bcftools stats $input_vcf > ${input_vcf.baseName}_stats.txt
    """
}

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

        println "Successfully read JSON file from S3: ${metadata}"

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

            // 4 - View raw input channel
            input_files_ch.view { "Raw input: ${it}" }

        
        // 4 - Dispatch processes based on classification
        VCF_STATS(input_files_ch.filter { it[0] == 'VCF' }.map { it[1] })

}

// workflow.onComplete {
//         onComplete:
//          println "Pipeline completed successfully! Clearing work directory..."
//         def workDir = workflow.workDir.toString()
//         if (workflow.profile == 'aws') {
//             println "Deleting S3 work directory: ${workDir}"
//             "aws s3 rm ${workDir} --recursive".execute()
//         } else {
//             println "Deleting local work directory: ${workDir}"
//             "rm -rf ${workDir}".execute()
//         }
// }
