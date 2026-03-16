// Helper functions


// Function to handle metadata and assign sample to each file
// If only has one file in a sample then id and sample names are the same 
// If multiple files in a sample then had sample and id with _1, _2, etc. suffixes
// If file is not assigned to a sample then id and sample name are file minus suffix (sam bam cram)


class SampleSheetParser {

    static List parseSampleSheet(metadata, file) {
        def sampleSheet = metadata.sampleSheet
        def sample_with_the_file = null
        def group_name = null

        // Step 1 - Grab the sample that contains the file of interest

        // Check groups first
        for (group in sampleSheet.groups) {
            for (sample in group.samples) {
                for (f in sample.files) {
                    if (f.name == file.name) {
                        sample_with_the_file = sample
                        group_name = group.name
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
                    group_name = null
                    break
                }
            }
        }

        
        if (sample_with_the_file != null) {
            // Step 2 - Assign sample and id based on how many files are in the sample
            if (sample_with_the_file.files.size() == 1) {
                return [sample_with_the_file.name, sample_with_the_file.name, group_name]
            } else {
                // Multiple files in the sample, assign based on file name suffix
                def baseName = sample_with_the_file.name
                def idx = sample_with_the_file.files.findIndexOf { it.name == file.name } + 1
                def suffix = "_${idx}"
                return ["${baseName}${suffix}", baseName, group_name]
            }
        }
        // If not found in any samples, assign based on file name minus suffix
        def baseName = file.name.replaceAll(/(_R?[12]|\.sam|\.bam|\.cram)?$/, '')
        return [baseName, baseName, null]

    }
}