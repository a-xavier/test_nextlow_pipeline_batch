process VEP_ANNOTATE {
    input:
    path vcf

    output:
    path "${vcf.baseName}_annotated.vcf"

    script:
    """
    vep \
      -i $vcf \
      --vcf \
      -o ${vcf.baseName}_annotated.vcf \
      --species homo_sapiens \
      --merged \
      --everything \
      --cache --offline \
      --dir_cache /references/VEP_Caches \
      --fork ${task.cpus} \
      --buffer_size 50000 \
      --fasta /references/Reference_Genomes/Human/GRCh38/Homo_sapiens.GRCh38.dna_sm.toplevel.fa
    """
}