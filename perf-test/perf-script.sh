#!/usr/bin/env bash

TOP_LEVEL_DIR=$(git rev-parse --show-toplevel)
APP_IMAGE="quay.io/openshift-logging/cluster-logging-load-client:0.1"
APP_STRUCTRED_NS="logger-structured"
APP_UNSTRUCTRED_NS="logger-unstructured"
REPLICAS=200
LOG_LINES_RATE=100
LOG_LINES_PER_INSTANCE=60000

function install-EO() {
  echo ">>> Installing elasticsearch operator"
  pushd "$TOP_LEVEL_DIR/../../openshift/elasticsearch-operator/"
  make elasticsearch-catalog-deploy
  make elasticsearch-operator-install
  popd
}

function cleanup-EO() {
  echo ">>> Cleaning up elasticsearch operator"
  pushd "$TOP_LEVEL_DIR/../../openshift/elasticsearch-operator/"
  make elasticsearch-cleanup
  popd
}

function install-CLO() {
  echo ">>> Installing cluster-logging operator"
  pushd "$TOP_LEVEL_DIR/../../openshift/cluster-logging-operator"
  make cluster-logging-catalog-deploy
  make cluster-logging-operator-install
  popd
}

function cleanup-CLO() {
  echo ">>> Cleaning up cluster-logging operator"
  pushd "$TOP_LEVEL_DIR/../../openshift/cluster-logging-operator"
  make cluster-logging-cleanup
  popd
}

function instantiate-CLO() {
  echo "Moving to project openshift-logging"
  oc project openshift-logging
  echo ">>> Instantiating CLO"
  oc create -n openshift-logging -f "$TOP_LEVEL_DIR/perf-test/cr.yaml"
  echo ">>> Installing rollover cronjob"
  oc create -n openshift-logging -f "$TOP_LEVEL_DIR/perf-test/rollover.yaml"
}

function create-app-namespaces() {
  echo ">>> Createing namespace $APP_STRUCTRED_NS"
  oc create ns "$APP_STRUCTRED_NS"

  echo ">>> Createing namespace $APP_UNSTRUCTRED_NS"
  oc create ns "$APP_UNSTRUCTRED_NS"
}

function deploy-log-forwarder() {
  echo ">>> Configuring log forwarder"
  oc process -f "$TOP_LEVEL_DIR/perf-test/logforwarder.yaml" \
    -p app_structured_ns="$APP_STRUCTRED_NS" \
    -p app_unstructured_ns="$APP_UNSTRUCTRED_NS" |
    oc apply -n openshift-logging -f -
}

function deploy-app-structured() {
  echo ">>> Deploying app structured"
  oc project "$APP_STRUCTRED_NS"
  oc process -f "$TOP_LEVEL_DIR/perf-test/app.yaml" \
    -p image="$APP_IMAGE" \
    -p replicas=$REPLICAS \
    -p log_lines_rate=$LOG_LINES_RATE \
    -p total_log_lines=$LOG_LINES_PER_INSTANCE \
    -p app_name="logger-structured" |
    oc apply -n "$APP_STRUCTRED_NS" -f -
}

function cleanup-app-structured() {
  echo ">>> Cleaning up app structured"
  oc delete ns "$APP_STRUCTRED_NS"
}

function deploy-app-unstructured() {
  echo ">>> Deploying app unstructured"
  oc project "$APP_UNSTRUCTRED_NS"
  oc process -f "$TOP_LEVEL_DIR/perf-test/app.yaml" \
    -p image="$APP_IMAGE" \
    -p replicas=$REPLICAS \
    -p log_lines_rate=$LOG_LINES_RATE \
    -p total_log_lines=$LOG_LINES_PER_INSTANCE \
    -p app_name="logger-unstructured" |
    oc apply -n "$APP_UNSTRUCTRED_NS" -f -
}

function cleanup-app-unstructured() {
  echo ">>> Cleaning up app unstructured"
  oc delete ns "$APP_UNSTRUCTRED_NS"
}

function deploy_ops() {
  install-EO
  install-CLO
  instantiate-CLO
}

function run() {
  create-app-namespaces
  deploy-log-forwarder
  echo ">>> Wait for fluentd pods to be ready"
  # "oc wait" is not enough as if no pods were created yet, it doesn't wait. That's why, "oc rollout" is run before.
  oc rollout status daemonset/fluentd
  oc wait --for=condition=ready pod -n openshift-logging -l component=fluentd
  deploy-app-unstructured
  echo ">>> Wait for 120 seconds to build stress on elasticsearch"
  sleep 120s
  deploy-app-structured
}

function cleanup_ops() {
  cleanup-CLO
  cleanup-EO
}

function cleanup_apps() {
  cleanup-app-structured
  cleanup-app-unstructured
}

function show_usage() {
  echo "help message"
}

function main() {
  for i in "$@"; do
    case $i in
    --deploy-ops)
      deploy_ops
      shift
      ;;
    --run)
      run
      shift
      ;;
    --cleanup-ops)
      cleanup_ops
      shift
      ;;
    --cleanup-apps)
      cleanup_apps
      shift
      ;;
    -h | --help | *) show_usage ;;
    esac
  done
}

main "$@"
