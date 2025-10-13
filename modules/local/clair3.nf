process CLAIR3 {
    tag "$meta.id"
    label 'process_medium'

    conda 'bioconda::clair3==1.0.4'
    container 'hkubal/clair3:v1.0.4'
    // Biocontainer not working for Clair3
    // -> See: https://github.com/HKU-BAL/Clair3/issues/98#issuecomment-1113949833
    //container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //    'https://depot.galaxyproject.org/singularity/clair3:1.0.4--py39hf5e1c6e_0' :
    //    'quay.io/biocontainers/clair3:1.0.4--py39hf5e1c6e_0' }"

    input:
    tuple val(meta), path(sizes), val(is_transcripts), path(input), path(index)
    path(fasta)
    path(fai)
    // optional model_path
    //path model_path

    output:
    tuple val(meta), path("${prefix}.vcf.gz")  ,  emit: vcf
    path "versions.yml"                        ,  emit: versions
    //path (clair3_dir), emit: output_dir
    //path (clair3_log), emit: log

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix   = task.ext.prefix ?: "${meta.id}"
    vcf          = "${prefix}.vcf.gz"
    clair3_dir   = "${prefix}.clair3"
    clair3_log   = "${clair3_dir}/run_clair3.log"
    def model_suffix = "models/${params.clair3_variant_model}"
    def using_conda = (workflow.containerEngine == null || workflow.containerEngine == '')
    """
    CLAIR_BIN_DIR=\$(dirname \$(which run_clair3.sh))
    if [[ "${params.clair3_user_variant_model}" != "" ]] ; then  # Re-enable that later ?
        MODEL_PATH="${params.clair3_user_variant_model}"
    else
        if [[ ${using_conda} = true ]] ; then
            MODEL_PATH="\$CLAIR_BIN_DIR/${model_suffix}"
        else [[ ${using_conda} = false ]]
            MODEL_PATH="/opt/models/${params.clair3_variant_model}"
            if [[ -d \$MODEL_PATH ]] ; then
                echo "Using built-in model: \$MODEL_PATH"
            else
                MODEL_PATH="/usr/local/bin/models/${params.clair3_variant_model}"
            fi
            if [[ ! -d \$MODEL_PATH ]] ; then
                echo "Model not found: \$MODEL_PATH"
                exit 1
            fi
        fi
    fi

    run_clair3.sh \\
        ${args} \\
        --bam_fn=${input} \\
        --ref_fn=$fasta \\
        --platform=ont \\
        --model_path="\$MODEL_PATH" \\
        --threads=${task.cpus} \\
        --output=${clair3_dir}

    ln -s ${clair3_dir}/merge_output.vcf.gz ${vcf}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        clair3: \$(head -n1 ${clair3_dir}/run_clair3.log | sed 's/^.*CLAIR3 VERSION: v//; s/ .*\$//')
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}
