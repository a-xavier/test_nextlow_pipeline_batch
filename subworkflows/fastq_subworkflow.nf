// Processes
include { FASTQC } from '../process/FASTQ/fastqc.nf'
include { SINGLE_FASTQ_ALIGNMENT } from '../process/FASTQ/single_fastq_alignment.nf'
include { PAIRED_FASTQ_ALIGNMENT } from '../process/FASTQ/paired_fastq_alignment.nf'
include { POST_ALIGNMENT_ANALYSIS } from '../process/BAM/post_alignment_analysis.nf'
include { MERGE_BAM_BY_SAMPLE_NAME } from '../process/BAM/merge_bam_by_sample_name.nf'
include { VARIANT_CALLING_DEEPVARIANT } from '../process/BAM/variant_calling_deepvariant.nf'
include { VARIANT_CALLING_HAPLOTYPE_CALLER } from '../process/BAM/variant_calling_haplotype_caller.nf'
include { VEP_ANNOTATE } from '../process/VCF/vcf_vep_annotation.nf'

workflow fastq_subworkflow {

    take:
        fastq_ch

    main:

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

        // Input fastq channel is ONE FOR EACH FILE 
        // Then group by LANE / KEY / SAMPLE
        //
        //  [
        //     analysis:[
        //         id:4cb03a1a-2140-4177-a15a-6531639515bd,
        //         name:My Comprehensive Genomic Sequencing (Human) Analysis 17-4-2026,
        //         selectedOptions:[human_reference_genome:GRCh38]],
        //         sample:[sample_id:s_1776379256331,
        //         sample_name:Bonbon,
        //         group_id:g_1776379257581,
        //         group_name:Group 1
        //         ],
            
        //     entity: [
        //         bioentity_id:1f7605c7-5379-4d5e-863f-dbf85d499b47,
        //         key:subsetted, platform:SHORT_READS,
        //         layout:PAIRED
        //         ],
                
        //     file:[
        //         lane_id:L000,
        //         read:R1,
        //         fastq_uri:s3://portalseq/Analysis/4cb03a1a-2140-4177-a15a-6531639515bd/Inputs/subsetted_1.fq.gz
        //         ]
        //  ]

        //=================================================
        // Set References with correct assembly 
        //================================================

                
        def assembly_ch = fastq_ch.map {item ->
            // Assuming all files have the same assembly, we can just take the first one
            return item.analysis.selectedOptions.human_reference_genome // Error if not there
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
        // s3://portalseq/references/dbSNP/Human/GRCH38/00-common_all.vcf.gz.tbi

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

        // External scripts just to make sure 
        def bed_coverage_maker_ch = channel.value(file("${projectDir}/bin/Experiment_Type_Detector.sh"))

        // fastq_ch.view { println "FASTQ Channel: ${it}" }

        //=================================================
        //                     FASTQC                    //
        //=================================================
        FASTQC(
            fastq_ch, 
            fastq_ch.map { metadata -> metadata.file.fastq_uri }
        )

        //=================================================
        //       Branch between SINGLE and PAIRED        //
        //=================================================

        def fq_branched = fastq_ch.branch {
            single : { metadata -> metadata.entity.layout == 'SINGLE' }
            paired : { metadata -> metadata.entity.layout == 'PAIRED' }
        }

        fastq_ch.count().view { println "Total FASTQ files: ${it}" }

       
        def single_fastq_ch = fastq_ch
            .filter { it.entity.layout == 'SINGLE' }

        def paired_fastq_ch = fastq_ch
            .filter { it.entity.layout == 'PAIRED' }
        

        // For pair ended we need to group first by lane and Key
        // We get all the file with same lane and key
        // THis shoudl leave 2 files in each group - R1 and R2
        // Furst we groupby
        def paired_keyed_ch = paired_fastq_ch
            .map { m ->

                def key = [
                    m.entity.bioentity_id,
                    m.file.lane_id
                ]

                tuple(
                    key,
                    m,
                    m.file.fastq_uri
                )
            }.groupTuple()

        // We rewrite the channel to ENSURE we have read1 THEN read 2 in the correct order for the paired alignment process
        def paired_align_ch = paired_keyed_ch
            .map { key, metas, fastqs ->

                assert metas.size() == 2
                assert fastqs.size() == 2

                def r1_pair = metas.withIndex()
                                .find { it[0].file.read == 'R1' }

                def r2_pair = metas.withIndex()
                                .find { it[0].file.read == 'R2' }

                assert r1_pair : "Missing R1 in paired group ${key}"
                assert r2_pair : "Missing R2 in paired group ${key}"

                def r1 = fastqs[r1_pair[1]]
                def r2 = fastqs[r2_pair[1]]

                def meta = metas[0]

                tuple(meta, r1, r2)
            }

        
        // =================================================
        //             SINGLE FASTQ ALIGNMENT              //
        // =================================================
        // Launch Single
        // output is 
        // tuple (sample_name, meta, bam)

        def single_fastq_result_bams_ch = SINGLE_FASTQ_ALIGNMENT(
            single_fastq_ch.map { metadata -> tuple(metadata, metadata.file.fastq_uri) }, // tuple of metadata and fastq path   
            alignment_reference_mmi_file_ch 
        )
        
        // =================================================
        //             PAIRED FASTQ ALIGNMENT              //
        // =================================================

        // Launch Paired by Lane
        // the output is tuple (sample_name, meta, bam)
        def paired_fastq_result_bams_ch = PAIRED_FASTQ_ALIGNMENT(
            paired_align_ch,
            alignment_reference_mmi_file_ch
        )

        //=================================================
        //         Group by Sample name for merging      //
        //=================================================
        def aligned_bam_ch = single_fastq_result_bams_ch.mix(paired_fastq_result_bams_ch)
        
        // Group by name and keep everything
        // because this is THE step where we rename the files based on sample name 
        def groupped_bam_chr = aligned_bam_ch.groupTuple()

        // Inputs is: tuple(sample_name, [identities], [bam_files])
        // Output is tuple(sample_name, [identities], merged_bam)
        //TODO: later we need to collapse identities to identities[0]
        def merged_bam_ch = MERGE_BAM_BY_SAMPLE_NAME(
            groupped_bam_chr
        )
        // Cleanup because identity is a list by now 
        def final_bam_ch = merged_bam_ch.map { sample_name, identities, bam_file ->
            tuple(sample_name, identities[0], bam_file)
        }

        //=================================================
        //         Post Alignment Analysis (QC)         //
        //=================================================

        // Do BQSR and Deduplication
        def (post_alignment_analysis_ch, _deu_metrics_ch ) = POST_ALIGNMENT_ANALYSIS(
            final_bam_ch,
            alignment_reference_fasta_ch,
            alignment_reference_fasta_index_ch,
            alignment_reference_fasta_dict_ch,
            common_variant_vcf_ch,
            common_variant_vcf_index_ch
        )

        // =================================================
        //         Variant Calling - Haplotype Caller      //
        // =================================================
        def (variant_calling_result_ch, gvcf_ch) = VARIANT_CALLING_HAPLOTYPE_CALLER(
            post_alignment_analysis_ch,
            alignment_reference_fasta_ch,
            alignment_reference_fasta_index_ch,
            alignment_reference_fasta_dict_ch,
            bed_coverage_maker_ch,
            common_variant_vcf_ch,
            common_variant_vcf_index_ch
        )

        // =================================================
        // Variant Annotation - VEP + dbNSFP + dbscSNV     //
        // =================================================
    //         input:
    //   tuple val(sample_name), val(identity), path(vcf)
    //   val vep_cache
    //   path fasta_reference
    //   path fasta_reference_index
    //   path fasta_reference_dict
    //   val assembly
    //   path dbNSFP_file
    //   path dbNSFP_file_index
    //   path dbscSNV_file
    //   path dbscSNV_file_index

        VEP_ANNOTATE(
            variant_calling_result_ch,
            params.vep_cache,
            alignment_reference_fasta_ch,
            alignment_reference_fasta_index_ch,
            alignment_reference_fasta_dict_ch,
            assembly_ch,
            dbNSFP_file_ch,
            dbNSFP_file_index_ch,
            dbscSNV_file_ch,
            dbscSNV_file_index_ch
        )
 }
