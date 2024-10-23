process BCFTOOLS_CONVERT {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.20--h8b25389_0':
        'biocontainers/bcftools:1.20--h8b25389_0' }"

    input:
    tuple val(meta), path(input), path(index)
    tuple val(meta2), path(fasta), path(fai)
    path(bed)

    output:
    tuple val(meta), path("*.{vcf,vcf.gz,bcf,bcf.gz}"), optional:true , emit: vcf
    tuple val(meta), path("*.hap.gz")                 , optional:true , emit: hap
    tuple val(meta), path("*.legend.gz")              , optional:true , emit: legend
    tuple val(meta), path("*.samples")                , optional:true , emit: samples
    path "versions.yml"                                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    def regions = bed ? "--regions-file $bed" : ""
    def reference = fasta ?  "--fasta-ref $fasta" : ""
    def extension = args.contains("--output-type b")   || args.contains("-Ob") ? "bcf.gz" :
                    args.contains("--output-type u")   || args.contains("-Ou") ? "bcf" :
                    args.contains("--output-type z")   || args.contains("-Oz") ? "vcf.gz" :
                    args.contains("--output-type v")   || args.contains("-Ov") ? "vcf" :
                    args.contains("--haplegendsample") || args.contains("-h")  ? "" :
                    "vcf.gz"

    input.collect{
        if (it.name == "${prefix}.${extension}") error "Input and output names are the same, set prefix in module configuration to disambiguate!"
    }

    """
    bcftools convert \\
        $args \\
        $regions \\
        --output ${prefix}.${extension} \\
        --threads $task.cpus \\
        $reference \\
        $input

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def extension = args.contains("--output-type b")   || args.contains("-Ob") ? "bcf.gz" :
                    args.contains("--output-type u")   || args.contains("-Ou") ? "bcf" :
                    args.contains("--output-type z")   || args.contains("-Oz") ? "vcf.gz" :
                    args.contains("--output-type v")   || args.contains("-Ov") ? "vcf" :
                    args.contains("--haplegendsample") || args.contains("-h")  ? "hap" :
                    "vcf.gz"
    def index_extension = args.contains("--write-index=tbi") || args.contains("-W=tbi") ? "tbi" :
                        args.contains("--write-index=csi") || args.contains("-W=csi") ? "csi" :
                        args.contains("--write-index") || args.contains("-W") ? "csi" :
                        ""
    def create_cmd = extension.endsWith(".gz") ? "echo '' | gzip >" : "touch"
    def create_index = extension.endsWith(".gz") && index_extension.matches("csi|tbi") ? "touch ${prefix}.${extension}.${index_extension}" : ""

    def create_legend = extension == "hap" ? "${create_cmd} ${prefix}.legend" : ""
    def create_sample = extension == "hap" ? "${create_cmd} ${prefix}.sample" : ""

    """
    ${create_cmd} ${prefix}.${extension}
    ${create_legend}
    ${create_sample}
    ${create_index}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$( bcftools --version |& sed '1!d; s/^.*bcftools //' )
    END_VERSIONS
    """
}
