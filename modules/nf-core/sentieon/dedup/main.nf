process SENTIEON_DEDUP {
    tag "$meta.id"
    label 'process_medium'
    label 'sentieon'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/sentieon:202308.02--ffce1b7074ce9924' :
        'nf-core/sentieon:202308.02--c641bc397cbf79d5' }"

    input:
    tuple val(meta), path(bam), path(bai)
    tuple val(meta2), path(fasta)
    tuple val(meta3), path(fasta_fai)

    output:
    tuple val(meta), path("*.cram")               , emit: cram, optional: true
    tuple val(meta), path("*.crai")               , emit: crai, optional: true
    tuple val(meta), path("*.bam")                , emit: bam , optional: true
    tuple val(meta), path("*.bai")                , emit: bai
    tuple val(meta), path("*.score")              , emit: score
    tuple val(meta), path("*.metrics")            , emit: metrics
    tuple val(meta), path("*.metrics.multiqc.tsv"), emit: metrics_multiqc_tsv
    path "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def args3 = task.ext.args3 ?: ''
    def args4 = task.ext.args4 ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def suffix = task.ext.suffix ?: ".cram"   // The suffix should be either ".cram" or ".bam".
    def metrics = task.ext.metrics ?: "${prefix}${suffix}.metrics"
    def input_list = bam.collect{"-i $it"}.join(' ')
    def sentieonLicense = secrets.SENTIEON_LICENSE_BASE64 ?
        "export SENTIEON_LICENSE=\$(mktemp);echo -e \"${secrets.SENTIEON_LICENSE_BASE64}\" | base64 -d > \$SENTIEON_LICENSE; " :
        ""
    """
    $sentieonLicense

    sentieon driver $args $input_list -r ${fasta} --algo LocusCollector $args2 --fun score_info ${prefix}.score
    sentieon driver $args3 -t $task.cpus $input_list -r ${fasta} --algo Dedup $args4 --score_info ${prefix}.score --metrics ${metrics} ${prefix}${suffix}
    # This following tsv-file is produced in order to get a proper tsv-file with Dedup-metrics for importing in MultiQC as "custom content".
    # It should be removed once MultiQC has a module for displaying Dedup-metrics.
    head -3 ${metrics} > ${metrics}.multiqc.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sentieon: \$(echo \$(sentieon driver --version 2>&1) | sed -e "s/sentieon-genomics-//g")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def suffix = task.ext.suffix ?: ".cram"   // The suffix should be either ".cram" or ".bam".
    def metrics = task.ext.metrics ?: "${prefix}${suffix}.metrics"
    """
    touch "${prefix}${suffix}"
    touch "${prefix}${suffix}\$(echo ${suffix} | sed 's/m\$/i/')"
    touch "${metrics}"
    touch "${metrics}.multiqc.tsv"
    touch "${prefix}.score"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sentieon: \$(echo \$(sentieon driver --version 2>&1) | sed -e "s/sentieon-genomics-//g")
    END_VERSIONS
    """
}
