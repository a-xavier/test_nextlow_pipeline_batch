process ZIP_PUBLISHDIR {

    publishDir "${params.publishDir}/Final_ZIP/", mode: 'copy'

    input:
     val tag
     val name_of_run
     val publishDir_Path // as file so we don't stage it if running local

    output:
        path "${name_of_run}_results.zip"

    script:
    // Here we take the publishdir and zip it and publish it in the same location. This is because some platforms (like Terra) can only download files smaller than 10GB, so we need to zip the output if it's larger than that. 
    def isS3 = params.profile_name == "awsbatch"
    if ( isS3 )
        """
        echo "=== AWS BATCH MODE: Zipping S3 Results ==="
        mkdir -p Result_Export
        
        # 1. Pull the already-published results from S3 to the 400GB local disk
        # We exclude the Final_ZIP folder itself to avoid recursive zipping
        aws s3 sync "${publishDir_Path}" Result_Export/ --exclude "Final_ZIP/*" --no-progress
        
        # 2. Create the zip archive
        # -r: recursive, -q: quiet (cleaner logs), -j: junk paths (optional, keeps zip flat)
        zip -r "${name_of_run}_results.zip" Result_Export/
        
        echo "Zip complete. Uploading to ${params.publishDir}/Final_ZIP/"
        """
    else
        """
        echo "=== LOCAL MODE: Zipping Local Results ==="
        # On local, we just zip the directory directly. 
        # We use -r to capture everything recursively.
        zip -r "${name_of_run}_results.zip" "${workflow.projectDir}/${publishDir_Path}"
        """
}