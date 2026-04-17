nextflow.enable.dsl=2

// Import all subworkflows
include { vcf_subworkflow } from './subworkflows/vcf_subworkflow.nf'
include { fastq_subworkflow } from './subworkflows/fastq_subworkflow.nf'
// Processes 
include { ZIP_PUBLISHDIR } from './process/OTHER/zip_publishdir.nf'

workflow {
    main:
        // 0 - Get the analysis ID from the command line arguments
        if (!params.analysis_id) {
            error "Missing required parameter: --analysis_id"
        } else {
            println "Analysis ID: ${params.analysis_id}"
        }

        // 1 - Access the json on s3
        def s3_json_path = "s3://portalseq/Analysis/${params.analysis_id}/Inputs/${params.analysis_id}_run.json"
       // Assign to metadata channel - this will be used to pass metadata to
       def metadata_ch = channel
        .fromPath(s3_json_path)
        .map { path -> 
            return new groovy.json.JsonSlurper().parse(path) 
        }

        // 2 - Split by bioentities 
        def bioentity_ch = metadata_ch
            .flatMap { meta ->
                meta.bioEntities.collect { be ->
                    tuple(meta, be)
                }
            }

        // 3 - Split by branch and classification

        def branched = bioentity_ch
            .branch {
                fastq : { meta, be -> be.payload?.kind == 'FASTQ_GROUP' }
                bam   : { meta, be -> be.payload?.kind == 'ALIGNMENT' }
                vcf   : { meta, be -> be.payload?.kind == 'VARIANT' }
                pod5  : { meta, be -> be.payload?.kind == 'POD5' }
                other : { meta, be -> true }
            }

        // 5 - Define nice inputs for each branch and call subworkflows

       
        def fastq_entity_ch = branched.fastq
            .map { meta, be ->

                def p = be.payload

                [
                    analysis : [
                        id      : meta.id,
                        name    : meta.analysisName,
                        selectedOptions : meta.selectedOptions   // ✅ assembly retained
                    ],

                    sample : ResolveSample.resolveSample(meta, p.key),

                    entity : [
                        bioentity_id : be.id,
                        key          : p.key,
                        platform     : p.platform,
                        layout       : p.layout
                    ],

                    lanes : p.lanes
                ]
            }

        // Handle file sources
        
        def fastq_file_ch = fastq_entity_ch
            .flatMap { m ->

                m.lanes.collect { lane ->

                    def laneFiles = (m.entity.layout == 'PAIRED')
                        ? [lane.R1, lane.R2]
                        : [lane.R1]

                    laneFiles.collect { fq ->

                        def input = fq.input

                        def uri = input.source == 'URL'
                            ? input.url
                            : "s3://portalseq/Analysis/${m.analysis.id}/Inputs/" +
                            input.file.path.replaceFirst('^\\./','')

                       
                    def resolved_sample_name = m.sample?.sample_name ?: m.entity.key
                    def resolved_group_name    = m.sample?.group_name    ?: null

                    def identity = [
                        sample_name : resolved_sample_name,
                        group_name  : resolved_group_name,
                        entity_key  : m.entity.key,
                        platform    : m.entity.platform
                    ]

                    [
                        analysis : m.analysis,
                        identity : identity,
                        entity   : m.entity,

                        file : [
                            lane_id : lane.laneId,
                            read    : fq.stats?.inferredRead,
                            fastq_uri   : file(uri)
                        ]
                    ]
                    }
                }.flatten()
            }
            // 6 Launch all subworkflows in parallel
            fastq_subworkflow(fastq_file_ch)
}

