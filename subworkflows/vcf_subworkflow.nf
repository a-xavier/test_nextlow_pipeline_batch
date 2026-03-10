include { VCF_STATS } from '../process/VCF/vcf_stats.nf'
include { VEP_ANNOTATE } from '../process/VCF/vcf_vep_annotation.nf'

workflow vcf_subworkflow {

    // Take input files + metadata from the main workflow
    take:
        combined_channel // COmbine metadata and VCF file channel into one channel of tuples: [metadata, vcf_file]

    main:
        // Call processes or subworkflows here, e.g.:
        // my_process(metadata_ch, input_vcf_ch)
        combined_channel.view { item -> println "Metadata: ${item[0]}" }
        combined_channel.view { item -> println "Input VCF: ${item[1]}" }

        VCF_STATS(combined_channel.map { item -> item[1] }) // Pass only the VCF file to the VCF_STATS process
        VEP_ANNOTATE(combined_channel.map { item -> item[1] })

}
