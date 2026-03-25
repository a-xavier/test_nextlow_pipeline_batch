include { VCF_STATS } from '../process/VCF/vcf_stats.nf'
include { VEP_ANNOTATE } from '../process/VCF/vcf_vep_annotation.nf'

workflow vcf_subworkflow {

    // Take input files + metadata from the main workflow
    take:
        combined_ch // COmbine metadata and VCF file channel into one channel of tuples: [metadata, vcf_file]

    main:

        // Reference channels (broadcasted to all samples)
        def assembly_ch = combined_ch.map {item ->
            def meta = item[0]
            // Assuming all files have the same assembly, we can just take the first one
            return meta.selectedOptions.human_reference_genome ?: 'GRCh38' // Default to GRCh38 if not specified
        }.first() // first to make sure we get a value channel instead of a collection

        // Reference channels (broadcasted to all samples)
        def alignment_reference_mmi_file_ch = assembly_ch.map { assembly ->
             file("${params.reference_dir}/Reference_Genomes/Human/${assembly}/Homo_sapiens.${assembly}.dna_sm.toplevel.mmi")
        } // if we put .first() we have warnings WARN: The operator `first` is useless when applied to a value channel which returns a single value by definition

        def alignment_reference_fasta_ch = assembly_ch.map { assembly ->
            file("${params.reference_dir}/Reference_Genomes/Human/${assembly}/Homo_sapiens.${assembly}.dna_sm.toplevel.fa")
        }

        def alignment_reference_fasta_index_ch = assembly_ch.map { assembly ->
            file("${params.reference_dir}/Reference_Genomes/Human/${assembly}/Homo_sapiens.${assembly}.dna_sm.toplevel.fa.fai")
        }

        def alignment_reference_fasta_dict_ch = assembly_ch.map { assembly ->
            file("${params.reference_dir}/Reference_Genomes/Human/${assembly}/Homo_sapiens.${assembly}.dna_sm.toplevel.dict")
        }

        def common_variant_vcf_ch = assembly_ch.map { assembly ->
            file("${params.reference_dir}/dbSNP/Human/${assembly}/00-common_all.vcf.gz")
        }

        def common_variant_vcf_index_ch = assembly_ch.map { assembly ->
            file("${params.reference_dir}/dbSNP/Human/${assembly}/00-common_all.vcf.gz.tbi")
        }

        def dbscSNV_file_ch = assembly_ch.map { assembly ->
            file("${params.reference_dir}/dbscSNV/${assembly}/dbscSNV1.1_${assembly}.txt.gz")
        }

         def dbscSNV_file_index_ch = assembly_ch.map { assembly ->
            file("${params.reference_dir}/dbscSNV/${assembly}/dbscSNV1.1_${assembly}.txt.gz.tbi")
        }

        def dbNSFP_file_ch = assembly_ch.map { assembly ->
            file("${params.reference_dir}/dbNSFP/${assembly}/dbNSFP4.9c_${assembly.toLowerCase()}.gz")
        }

        def dbNSFP_file_index_ch = assembly_ch.map { assembly ->
            file("${params.reference_dir}/dbNSFP/${assembly}/dbNSFP4.9c_${assembly.toLowerCase()}.gz.tbi")
        }

        // Call processes or subworkflows here, e.g.:
        // my_process(metadata_ch, input_vcf_ch)
        combined_ch.view { item -> println "Metadata: ${item[0]}" }
        combined_ch.view { item -> println "Input VCF: ${item[1]}" }

        VCF_STATS(combined_ch.map { item -> item[1] }) // Pass only the VCF file to the VCF_STATS process
        
        annotated_vcf_ch = VEP_ANNOTATE(
            combined_ch.map { item -> item[1] }, // VCF file
            channel.value(params.vep_cache),
            alignment_reference_fasta_ch,
            alignment_reference_fasta_index_ch,
            alignment_reference_fasta_dict_ch,
            assembly_ch,
            dbNSFP_file_ch,
            dbNSFP_file_index_ch,
            dbscSNV_file_ch,
            dbscSNV_file_index_ch
        )

    emit:
        final_files_vcf = annotated_vcf_ch



}
