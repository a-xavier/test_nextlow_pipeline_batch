include { VCF_STATS } from '../process/VCF/vcf_stats.nf'
include { VEP_ANNOTATE } from '../process/VCF/vcf_vep_annotation.nf'

workflow vcf_subworkflow {

    // Take input files + metadata from the main workflow
    take:
        combined_channel // COmbine metadata and VCF file channel into one channel of tuples: [metadata, vcf_file]

    main:

        // Reference channels (broadcasted to all samples)
        def alignment_reference_mmi_file_ch = channel.value(file("${params.reference_dir}/Reference_Genomes/Human/GRCh38/Homo_sapiens.GRCh38.dna_sm.toplevel.mmi"))
        def alignment_reference_fasta_ch = channel.value(file("${params.reference_dir}/Reference_Genomes/Human/GRCh38/Homo_sapiens.GRCh38.dna_sm.toplevel.fa"))
        def alignment_reference_fasta_index_ch = channel.value(file("${params.reference_dir}/Reference_Genomes/Human/GRCh38/Homo_sapiens.GRCh38.dna_sm.toplevel.fa.fai"))
        def alignment_reference_fasta_dict_ch = channel.value(file("${params.reference_dir}/Reference_Genomes/Human/GRCh38/Homo_sapiens.GRCh38.dna_sm.toplevel.dict"))
        def common_variant_vcf_ch = channel.value(file("${params.reference_dir}/dbSNP/Human/GRCH38/00-common_all.vcf.gz"))
        def common_variant_vcf_index_ch = channel.value(file("${params.reference_dir}/dbSNP/Human/GRCH38/00-common_all.vcf.gz.tbi"))
        def fastqc_report_parser_ch = channel.value(file("${projectDir}/bin/parse_fastqc_report.sh"))

        // Call processes or subworkflows here, e.g.:
        // my_process(metadata_ch, input_vcf_ch)
        combined_channel.view { item -> println "Metadata: ${item[0]}" }
        combined_channel.view { item -> println "Input VCF: ${item[1]}" }

        VCF_STATS(combined_channel.map { item -> item[1] }) // Pass only the VCF file to the VCF_STATS process
        annotated_vcf_ch = VEP_ANNOTATE(
            combined_channel.map { item -> item[1] }, // VCF file
            channel.value(params.vep_cache),
            alignment_reference_fasta_ch,
            alignment_reference_fasta_index_ch,
            alignment_reference_fasta_dict_ch
        )

    emit:
        final_files_vcf = annotated_vcf_ch



}
