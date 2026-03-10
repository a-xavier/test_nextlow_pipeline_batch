include { VCF_STATS } from '../process/VCF/vcf_stats.nf'
include { VEP_ANNOTATE } from '../process/VCF/vcf_vep_annotation.nf'

workflow vcf_subworkflow {

    // Take input files + metadata from the main workflow
    take:
        metadata_ch // always the same
        input_vcf_ch // name of a file

    main:
        // Call processes or subworkflows here, e.g.:
        // my_process(metadata_ch, input_vcf_ch)
        metadata_ch.view { println "Metadata: ${it}" }
        input_vcf_ch.view { println "Input VCF: ${it}" }

        VCF_STATS(input_vcf_ch)
        VEP_ANNOTATE(input_vcf_ch)

}
