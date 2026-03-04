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
    publishDir "s3://test-nextflow-pipeline/results", mode: 'copy'
    
    // Logic: Receive the file 'x' (test.txt), modify it, and output it again
    input: path x
    output: path x

    script:
    """
    echo "Hello World" > $x
    """
}

workflow {
    main:
    STEP_ONE | STEP_TWO
}

workflow.onComplete {
    if (workflow.success) {
        println "Pipeline completed successfully! Clearing S3 work directory..."
        "aws s3 rm ${workflow.workDir} --recursive".execute()
    }
}