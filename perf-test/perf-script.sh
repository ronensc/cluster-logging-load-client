#!/usr/bin/env bash

TOP_LEVEL_DIR=$(git rev-parse --show-toplevel)
APP_IMAGE="docker.io/ronensch/cluster-logging-load-client:latest"
APP_STRUCTRED_NS="logger-structured"
APP_UNSTRUCTRED_NS="logger-unstructured"
REPLICAS=200
LOG_LINES_RATE=10
LOG_LINES_PER_INSTANCE=10000

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
    -p app_unstructured_ns="$APP_UNSTRUCTRED_NS" \
  | oc apply -n openshift-logging -f -
}

function deploy-app-structured() {
  echo ">>> Deploying app structured"
  oc project "$APP_STRUCTRED_NS"
  oc process -f "$TOP_LEVEL_DIR/perf-test/app.yaml" \
    -p image="$APP_IMAGE" \
    -p replicas=$REPLICAS \
    -p log_lines_rate=$LOG_LINES_RATE \
    -p total_log_lines=$LOG_LINES_PER_INSTANCE \
    -p app_name="logger-structured" \
  | oc apply -n "$APP_STRUCTRED_NS" -f -
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
    -p app_name="logger-unstructured" \
  | oc apply -n "$APP_UNSTRUCTRED_NS" -f -
}

function cleanup-app-unstructured() {
  echo ">>> Cleaning up app unstructured"
  oc delete ns "$APP_UNSTRUCTRED_NS"
}

function run() {
  if [ -z "$SKIP_OPS" ]; then
    install-EO
    install-CLO
    instantiate-CLO
  fi
  create-app-namespaces
  deploy-log-forwarder
  deploy-app-unstructured
  deploy-app-structured
}

function cleanup() {
  cleanup-app-structured
  cleanup-app-unstructured
  if [ -z "$SKIP_OPS" ]; then
    cleanup-CLO
    cleanup-EO
  fi
}

function show_usage() {
  echo "help message"
}

function main() {
  for i in "$@"
  do
  case $i in
      --skip-ops) SKIP_OPS=1; shift ;;
      --run) run; shift ;;
      --cleanup) cleanup; shift ;;
      -h|--help|*) show_usage ;;
  esac
  done
}

main "$@"