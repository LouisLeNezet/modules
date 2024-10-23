process BCFTOOLS_ANNOTATE {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.20--h8b25389_0':
        'biocontainers/bcftools:1.20--h8b25389_0' }"

    input:
    tuple val(meta), path(input), path(index), path(annotations), path(annotations_index)
    path(header_lines)

    output:
    tuple val(meta), path("*.{vcf.gz,bcf,bcf.gz}"), emit: vcf
    tuple val(meta), path("*.{tbi,csi}")          , emit: index, optional: true
    path "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args    = task.ext.args ?: ''
    def prefix  = task.ext.prefix ?: "${meta.id}"
    def header_file = header_lines ? "--header-lines ${header_lines}" : ''
    def annotations_file = annotations ? "--annotations ${annotations}" : ''

    def index_names = index.findAll { file -> !(file instanceof List) }.collect { file -> file.name }
    def create_input_index = input.collect {
        vcf -> index_names =~ "(${vcf.name})\\.(tbi|csi)" ? "" : "tabix ${vcf}"
    }.join("\n")

    def extension = getInputExtension(args)

    input.collect{
        if (it.name == "${prefix}.${extension}") error "Input and output names are the same, set prefix in module configuration to disambiguate!"
    }

    """
    ${create_input_index}

    bcftools \\
        annotate \\
        $args \\
        $annotations_file \\
        $header_file \\
        --output ${prefix}.${extension} \\
        --threads $task.cpus \\
        $input

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$( bcftools --version |& sed '1!d; s/^.*bcftools //' )
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def input_extension = getInputExtension(args)
    def index_extension = getIndexExtension(args)
    def create_cmd = input_extension.endsWith(".gz") ? "echo '' | gzip >" : "touch"
    def create_index = input_extension.endsWith(".gz") && index_extension.matches("csi|tbi") ? "touch ${prefix}.${input_extension}.${index_extension}" : ""

    input.collect{
        if (it.name == "${prefix}.${input_extension}") error "Input and output names are the same, set prefix in module configuration to disambiguate!"
    }

    """
    ${create_cmd} ${prefix}.${input_extension}
    ${create_index}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$( bcftools --version |& sed '1!d; s/^.*bcftools //' )
    END_VERSIONS
    """
}

// Custom Functions
String getInputExtension(String args) {
    return args.contains("--output-type b") || args.contains("-Ob") ? "bcf.gz" :
        args.contains("--output-type u") || args.contains("-Ou") ? "bcf" :
        args.contains("--output-type z") || args.contains("-Oz") ? "vcf.gz" :
        args.contains("--output-type v") || args.contains("-Ov") ? "vcf" :
        "vcf.gz"
}

String getIndexExtension(String args) {
    return args.contains("--write-index=tbi") || args.contains("-W=tbi") ? "tbi" :
        args.contains("--write-index=csi") || args.contains("-W=csi") ? "csi" :
        args.contains("--write-index") || args.contains("-W") ? "csi" :
        ""
}
