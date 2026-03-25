// Processes
include { FASTQC } from '../process/FASTQ/fastqc.nf'
include { SINGLE_FASTQ_ALIGNMENT } from '../process/FASTQ/single_fastq_alignment.nf'
include { POST_ALIGNMENT_ANALYSIS } from '../process/BAM/post_alignment_analysis.nf'
include { MERGE_BAM_BY_SAMPLE_NAME } from '../process/BAM/merge_bam_by_sample_name.nf'
include { VARIANT_CALLING_DEEPVARIANT } from '../process/BAM/variant_calling_deepvariant.nf'
include { VARIANT_CALLING_HAPLOTYPE_CALLER } from '../process/BAM/variant_calling_haplotype_caller.nf'
include { VEP_ANNOTATE } from '../process/VCF/vcf_vep_annotation.nf'

workflow single_fastq_subworkflow {

    take:
        combined_ch // [metadata, single_fastq_file]

    main:
        println "Running single FASTQ subworkflow"

        // From metadata set assembly channel - to decide which reference we are going to use:
        // TODO: Cleanup this into a better process
        // Maybe return a channel of references instead of individual channels
        //     def references_ch = combined_ch.map { item ->
        //     def meta = item[0]
        //     def assembly = meta.selectedOptions.human_reference_genome ?: 'GRCh38'
        //     def ref_dir = params.reference_dir
        //     [
        //         mmi: file("${ref_dir}/Reference_Genomes/Human/${assembly}/Homo_sapiens.${assembly}.dna_sm.toplevel.mmi"),
        //         fasta: file("${ref_dir}/Reference_Genomes/Human/${assembly}/Homo_sapiens.${assembly}.dna_sm.toplevel.fa"),
        //         fasta_index: file("${ref_dir}/Reference_Genomes/Human/${assembly}/Homo_sapiens.${assembly}.dna_sm.toplevel.fa.fai"),
        //         fasta_dict: file("${ref_dir}/Reference_Genomes/Human/${assembly}/Homo_sapiens.${assembly}.dna_sm.toplevel.dict"),
        //         common_vcf: file("${ref_dir}/dbSNP/Human/${assembly}/00-common_all.vcf.gz"),
        //         common_vcf_index: file("${ref_dir}/dbSNP/Human/${assembly}/00-common_all.vcf.gz.tbi"),
        //         dbscSNV: file("${ref_dir}/dbscSNV/${assembly}/dbscSNV1.1_${assembly}.txt.gz"),
        //         dbscSNV_index: file("${ref_dir}/dbscSNV/${assembly}/dbscSNV1.1_${assembly}.txt.gz.tbi"),
        //         dbNSFP: file("${ref_dir}/dbNSFP/${assembly}/dbNSFP4.9c_${assembly.toLowerCase()}.gz"),
        //         dbNSFP_index: file("${ref_dir}/dbNSFP/${assembly}/dbNSFP4.9c_${assembly.toLowerCase()}.gz.tbi")
        //     ]
        // }.first() /

                
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





        // Parser script just to make sure 
        def parser_script_ch = channel.value(file("${projectDir}/bin/parse_fastqc_report.sh"))
        def bed_coverage_maker_ch = channel.value(file("${projectDir}/bin/Experiment_Type_Detector.sh"))

        // Combined Channel is invariable and will be used for all inputs before merging
        
        // combined_ch.view { tuple ->
        //     def metadata = tuple[0]
        //     def file_classification = tuple[1]
        //     def file_path = tuple[2]
        //     def sample_id = tuple[3]
        //     def sample_name = tuple[4]
        //     def group_name = tuple[5]
        //     println "########################"
        //     println "File Classification: ${file_classification}"
        //     println "File Path: ${file_path}"
        //     println "Sample ID: ${sample_id}"
        //     println "Sample Name: ${sample_name}"
        //     println "Group Name: ${group_name}"
        //     println "########################"
        // }

        // 1 - QC with FastQC
        // Input is the combined channel
        // Output is tuple path(fastq), path(preset_file) and the fastqc zip file (not used further but published)
        def (fastqc_output_ch, _metrics_ch) = FASTQC( combined_ch, parser_script_ch )

        // fastqc_output_ch.view { tuple -> 
        //     def fastq_path = tuple[0]
        //     def preset_file_path = tuple[1]
        //     println "FastQC Output for Unique ID ${unique_id}: Fastq Path: ${fastq_path}, Preset File Path: ${preset_file_path}"
        // }
        
        // 2 - Alignment with minimap2 or bowtie2
        // Input is the fastqc output channel path(fastq), path(preset_file) ) and the reference mmi file channel
        // Output is the aligned bam file
        def aligned_bam_ch = SINGLE_FASTQ_ALIGNMENT( fastqc_output_ch, alignment_reference_mmi_file_ch)

        // // aligned_bam_ch.view { item -> 
        // //     def aligned_bam_path = item
        // //     println "Aligned BAM for Unique ID ${unique_id}: ${aligned_bam_path}"
        // // }

        // // 3 - Post alignment analysis with GATK BQSR and MarkDuplicates
        // TODO: DeepVariant says to not use BQSR scores so there is a tage called --parse_sam_aux_fields, --use_original_quality_scores
        // // Output is  tuple val(sample_name), path("${aligned_bam_file.baseName}_analysis_ready.bam"), val(sample_id), val(file_unique_id)

        // This step is important to synchronise stuff so -resume works as intended
        // Join by sample_id
        def post_align_input_ch = combined_ch
            .map { meta, classification, path, id, name, group -> [ id, meta, classification, path, name, group ] }
            .join( aligned_bam_ch ) 
            .join( fastqc_output_ch.map { id, _fastq, preset -> [ id, preset ] } )

        def (post_alignment_analysis_ch, _dup_metrics_ch) = POST_ALIGNMENT_ANALYSIS(
            post_align_input_ch,
            alignment_reference_fasta_ch,
            alignment_reference_fasta_index_ch,
            alignment_reference_fasta_dict_ch,
            common_variant_vcf_ch,
            common_variant_vcf_index_ch
        )

        //  // 4 Merge the analysis by sample name 
        //  // group by sample name from post_alignment_analysis_ch 


        // // THe groupping changes the structure and we get 
        // // [ Sample_Name, [analysis_ready_1.bam, analysis_ready_2.bam, ...], [Sample_ID_1, Sample_ID_2, ...]]
        // // for each sample name

        def merge_bam_output_ch =  MERGE_BAM_BY_SAMPLE_NAME(
            post_alignment_analysis_ch.groupTuple() // group by first item in tuple
            )
        
        // 5 - Variant calling
        // Inputs outputs are
        // input:
        //         tuple val(sample_name), path(aligned_bam_file) // No sample id because we are done with it by now
        //         path fasta_reference
        //         path fasta_index
        //         path fasta_dict
        // output:
        //     path "${aligned_bam_file.baseName}_variants.vcf.gz"
        //     path "${aligned_bam_file.baseName}_variants.g.vcf.gz"
        
        // def (_gvcf_ch, vcf_ch) = VARIANT_CALLING_DEEPVARIANT(
        //         merge_bam_output_ch,
        //         alignment_reference_fasta_ch,
        //         alignment_reference_fasta_index_ch,
        //         alignment_reference_fasta_dict_ch
        //     )

        def (_gvcf_ch, vcf_ch) = VARIANT_CALLING_HAPLOTYPE_CALLER(
            merge_bam_output_ch,
            alignment_reference_fasta_ch,
            alignment_reference_fasta_index_ch,
            alignment_reference_fasta_dict_ch,
            bed_coverage_maker_ch,
            common_variant_vcf_ch,
            common_variant_vcf_index_ch
        )

        // 6 - VEP annotation
        def annotated_vcf_ch = VEP_ANNOTATE(
            vcf_ch,
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
        final_files_single_fastq = annotated_vcf_ch // [sample_name, annotated_vcf_file]


}