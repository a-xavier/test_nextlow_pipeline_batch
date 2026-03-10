include { VCF_STATS } from '../process/VCF/vcf_stats.nf'
include { VEP_ANNOTATE } from '../process/VCF/vcf_vep_annotation.nf'

workflow vcf_subworkflow {

    // Take input files + metadata from the main workflow
    take:
        combined_channel // COmbine metadata and VCF file channel into one channel of tuples: [metadata, vcf_file]

    main:
        // Call processes or subworkflows here, e.g.:
        // my_process(metadata_ch, input_vcf_ch)
        combined_channel.view { println "Metadata: ${it[0]}" }
        combined_channel.view { println "Input VCF: ${it[1]}" }

        VCF_STATS(combined_channel.map { it[1] })
        VEP_ANNOTATE(combined_channel.map { it[1] })

}
