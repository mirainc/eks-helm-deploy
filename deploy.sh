#!/usr/bin/env bash

initialize () {
    # Login to Kubernetes Cluster.
    UPDATE_KUBECONFIG_COMMAND="aws eks --region ${AWS_REGION} update-kubeconfig --name ${CLUSTER_NAME}"
    if [ -n "$CLUSTER_ROLE_ARN" ]; then
        UPDATE_KUBECONFIG_COMMAND="${UPDATE_KUBECONFIG_COMMAND} --role-arn=${CLUSTER_ROLE_ARN}"
    fi
    ${UPDATE_KUBECONFIG_COMMAND}

    # Helm Dependency Update
    helm dependency update ${DEPLOY_CHART_PATH:-helm/}

    # Add repository.  The user doesn't supply a name, and it's only temporary,
    # until the install command, so just hardcode the name to "current"
    if [ -n "$REPOSITORY" ]; then
        helm repo add current "$REPOSITORY"
    fi
}

helm_install_or_diff () {
    # Helm Deployment
    if [ "$DIFF" = true ]; then
        UPGRADE_COMMAND="helm diff upgrade --color --wait --atomic --install --timeout ${TIMEOUT}"
    else
        UPGRADE_COMMAND="helm upgrade --wait --atomic --install --timeout ${TIMEOUT}"
    fi

    for config_file in ${DEPLOY_CONFIG_FILES//,/ }
    do
        UPGRADE_COMMAND="${UPGRADE_COMMAND} -f ${config_file}"
    done
    if [ -n "$DEPLOY_NAMESPACE" ]; then
        UPGRADE_COMMAND="${UPGRADE_COMMAND} -n ${DEPLOY_NAMESPACE}"
    fi
    if [ -n "$DEPLOY_VALUES" ]; then
        UPGRADE_COMMAND="${UPGRADE_COMMAND} --set ${DEPLOY_VALUES}"
    fi
    if [ "$DEBUG" = true ]; then
        UPGRADE_COMMAND="${UPGRADE_COMMAND} --debug"
    fi
    if [ "$DRY_RUN" = true ]; then
        UPGRADE_COMMAND="${UPGRADE_COMMAND} --dry-run"
    fi

    # Restructure chart name to repo/chart, if a repo was specified.  It's
    # hardcoded to "current" above.
    if [ -n "$REPOSITORY" ]; then
        # Chart is a repository
        if [ -z "$DEPLOY_CHART_PATH" ]; then
            echo "Must specify a chart if pulling from a repository"
            exit 1
        fi
        chart=current/"$DEPLOY_CHART_PATH"
    else
        # Chart is a path.  Default to helm/.
        chart=${DEPLOY_CHART_PATH:-helm/}
    fi

    UPGRADE_COMMAND="${UPGRADE_COMMAND} ${DEPLOY_NAME} $chart"

    echo "Executing: ${UPGRADE_COMMAND}"
    ${UPGRADE_COMMAND}
}

helm_uninstall () {
    # Uninstall the Helm chart.

    # `diff uninstall` doesn't exist.  Just do a regular dry-run in that case
    if [ "$DIFF" = true ]; then
        DRY_RUN="$DIFF"
    fi

    UNINSTALL_COMMAND="helm uninstall --wait --timeout ${TIMEOUT}"
    if [ -n "$DEPLOY_NAMESPACE" ]; then
        UNINSTALL_COMMAND="${UNINSTALL_COMMAND} -n ${DEPLOY_NAMESPACE}"
    fi
    if [ "$DEBUG" = true ]; then
        UNINSTALL_COMMAND="${UNINSTALL_COMMAND} --debug"
    fi
    if [ "$DRY_RUN" = true ]; then
        UNINSTALL_COMMAND="${UNINSTALL_COMMAND} --dry-run"
    fi
    UNINSTALL_COMMAND="${UNINSTALL_COMMAND} ${DEPLOY_NAME}"
    echo "Executing: ${UNINSTALL_COMMAND}"
    ${UNINSTALL_COMMAND}
}

initialize
if [ "$UNINSTALL" = true ]; then
    helm_uninstall
else
    helm_install_or_diff
fi
