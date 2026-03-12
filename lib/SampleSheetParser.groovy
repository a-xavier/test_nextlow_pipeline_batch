// Helper functions


// Function to handle metadata and assign sample to each file
// If only has one file in a sample then id and sample names are the same 
// If multiple files in a sample then had sample and id with _1, _2, etc. suffixes
// If file is not assigned to a sample then id and sample name are file minus suffix (sam bam cram)


class SampleSheetParser {

    static List parseSampleSheet(metadata, file) {
        def sampleSheet = metadata.sampleSheet
        def sample_with_the_file = null

        // Step 1 - GRab the sample that contains the file opf interest

        // Check groups first
        for (group in sampleSheet.groups) {
            for (sample in group.samples) {
                for (f in sample.files) {
                    if (f.name == file.name) {
                        sample_with_the_file = sample
                        // Break out of all loops once found
                        break
                    }
                }
            }
        }

        // Check ungrouped samples next
        for (sample in sampleSheet.ungroupedSamples) {
            for (f in sample.files) {
                if (f.name == file.name) {
                    sample_with_the_file = sample
                    // Break out of all loops once found
                    break
                }
            }
        }

        
        println "Sample with the file: ${sample_with_the_file}"
        println "All files for this sample: ${sample_with_the_file.files}"
        
        if (sample_with_the_file != null) {
            // Step 2 - Assign sample and id based on how many files are in the sample
            if (sample_with_the_file.files.size() == 1) {
                
                print "Sample ID: ${sample_with_the_file.name} - Sample Name: ${sample_with_the_file.name} "

                return [sample_with_the_file.name, sample_with_the_file.name]
            } else {
                // Multiple files in the sample, assign based on file name suffix
                def suffix = file.name.replaceAll(/.*(_R?[12]|\.sam|\.bam|\.cram)$/, '$1')
                def baseName = sample_with_the_file.name

                println "Sample ID: ${baseName}${suffix} - Sample Name: ${baseName}"

                return ["${baseName}${suffix}", baseName]
            }
        }


        // If not found in any samples, assign based on file name minus suffix
        def baseName = file.name.replaceAll(/(_R?[12]|\.sam|\.bam|\.cram)?$/, '')

        println "Sample ID: ${baseName} - Sample Name: ${baseName}"

        return [baseName, baseName]

    }
}