// Processes
include { FASTQC } from '../process/FASTQ/fastqc.nf'
include { SINGLE_FASTQ_ALIGNMENT } from '../process/FASTQ/single_fastq_alignment.nf'
include { POST_ALIGNMENT_ANALYSIS } from '../process/BAM/post_alignment_analysis.nf'
include { MERGE_BAM_BY_SAMPLE_NAME } from '../process/BAM/merge_bam_by_sample_name.nf'

workflow single_fastq_subworkflow {

    take:
        combined_ch // [metadata, single_fastq_file]

    main:
        println "Running single FASTQ subworkflow"

        // Reference channels (broadcasted to all samples)
        def alignment_reference_mmi_file_ch = channel.value(file("${params.reference_dir}/Reference_Genomes/Human/GRCh38/Homo_sapiens.GRCh38.dna_sm.toplevel.mmi"))
        def alignment_reference_fasta_ch = channel.value(file("${params.reference_dir}/Reference_Genomes/Human/GRCh38/Homo_sapiens.GRCh38.dna_sm.toplevel.fa"))
        def alignment_reference_fasta_index_ch = channel.value(file("${params.reference_dir}/Reference_Genomes/Human/GRCh38/Homo_sapiens.GRCh38.dna_sm.toplevel.fa.fai"))
        def alignment_reference_fasta_dict_ch = channel.value(file("${params.reference_dir}/Reference_Genomes/Human/GRCh38/Homo_sapiens.GRCh38.dna_sm.toplevel.dict"))
        def common_variant_vcf_ch = channel.value(file("${params.reference_dir}/dbSNP/Human/GRCH38/00-common_all.vcf.gz"))
        def common_variant_vcf_index_ch = channel.value(file("${params.reference_dir}/dbSNP/Human/GRCH38/00-common_all.vcf.gz.tbi"))
        def fastqc_report_parser_ch = channel.value(file("${projectDir}/bin/parse_fastqc_report.sh"))

        // Parser script just to make sure 
        def parser_script_ch = channel.value(file("${projectDir}/bin/parse_fastqc_report.sh"))

        // Combined Channel is invariable and will be used for all inputs before merging
        // combined_ch.view { tuple -> 

        //     def metadata = tuple [0]
        //     def file_unique_id = tuple [1]
        //     def file_classification = tuple [2]
        //     def file_path = tuple [3]
        //     def sample_id = tuple [4]
        //     def sample_name = tuple [5]
        //     def group_name = tuple [6]
            
        //     println "########################"
        //     println "File Unique ID: ${file_unique_id}"
        //     println "File Classification: ${file_classification}"
        //     println "File Path: ${file_path}"
        //     println "Sample ID: ${sample_id}"
        //     println "Sample Name: ${sample_name}"
        //     println "Group Name: ${group_name}"
        //     println "########################"
        //  }

        // 1 - QC with FastQC
        // Input is the combined channel
        // Output is tuple val(unique_id), path(fastq), path(preset_file) and the fastqc zip file (not used further but published)
        def (fastqc_output_ch, _metrics_ch) = FASTQC( combined_ch, parser_script_ch )

        // fastqc_output_ch.view { tuple -> 
        //     def unique_id = tuple[0]
        //     def fastq_path = tuple[1]
        //     def preset_file_path = tuple[2]
        //     println "FastQC Output for Unique ID ${unique_id}: Fastq Path: ${fastq_path}, Preset File Path: ${preset_file_path}"
        // }
        
        // 2 - Alignment with minimap2 or bowtie2
        // Input is the fastqc output channel (tuple val(unique_id), path(fastq), path(preset_file) ) and the reference mmi file channel
        // Output is unique_id and the aligned bam file
        def aligned_bam_ch = SINGLE_FASTQ_ALIGNMENT( fastqc_output_ch, alignment_reference_mmi_file_ch)

        // aligned_bam_ch.view { tuple -> 
        //     def unique_id = tuple[0]
        //     def aligned_bam_path = tuple[1]
        //     println "Aligned BAM for Unique ID ${unique_id}: ${aligned_bam_path}"
        // }

        // 3 - Post alignment analysis with GATK 
        // THis one is hard to construct
        // This is combined channel
        // tuple val(metadata), val(file_unique_id), val(file_classification), val(file_path), val(sample_id), val(sample_name), val(group_name)
        // path aligned_bam_file // from aligned_bam_ch
        // path preset_file // from fastqc_output_ch
        // path fasta_reference // from alignment_reference_fasta_ch
        // path fasta_reference_index // from alignment_reference_fasta_index_ch
        // path fasta_reference_dict // from alignment_reference_fasta_dict_ch
        // path common_variant_vcf // from common_variant_vcf_ch
        // path common_variant_vcf_index // from common_variant_vcf_index_ch

        // Output is  tuple val(sample_name), path("${aligned_bam_file.baseName}_analysis_ready.bam"), val(sample_id), val(file_unique_id)


        def (post_alignment_analysis_ch, _dup_metrics_ch) = POST_ALIGNMENT_ANALYSIS(
            combined_ch,
            aligned_bam_ch.map { it[1] },
            fastqc_output_ch.map{ it[2] },
            alignment_reference_fasta_ch,
            alignment_reference_fasta_index_ch,
            alignment_reference_fasta_dict_ch,
            common_variant_vcf_ch,
            common_variant_vcf_index_ch
            )

         // 4 Merge the analysis by sample name 
         // group by sample name from post_alignment_analysis_ch 


        // THe groupping changes the structure and we get 
        // [ Sample_Name, [analysis_ready_1.bam, analysis_ready_2.bam, ...], [Sample_ID_1, Sample_ID_2, ...], [[unique_id_1, unique_id_2, ...]] ]
        // for each sample name 

        MERGE_BAM_BY_SAMPLE_NAME(
            post_alignment_analysis_ch.groupTuple() // group by first item in tuple
            ) 

        



}