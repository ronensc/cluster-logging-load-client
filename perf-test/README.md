# How to use 
Setup
```
./perf-test/perf-script.sh --deploy-ops
```

Run test
```
./perf-test/perf-script.sh --run
```

Cleanup
```
./perf-test/perf-script.sh --cleanup-apps --cleanup-ops
```


## Useful commands

List indices
```
oc exec -it -n openshift-logging $(oc get po -n openshift-logging -l "component=elasticsearch" -o jsonpath={.items[0].metadata.name}) -- es_util --query="_cat/indices?v=true"
```


Query 3 last documents of an index
```
export Q_INDEX="app-myformat-000001" && \
echo '{
    "size": 3,
    "sort": { "@timestamp": "desc"},
    "query": {
        "match_all": {}
    }
}' | oc exec -i -n openshift-logging $(oc get po -n openshift-logging -l "component=elasticsearch" -o name | head -n1) -- es_util --query="$Q_INDEX/_search" -d @- | jq .
```


Query pending tasks
```
oc exec -it -n openshift-logging $(oc get po -n openshift-logging -l "component=elasticsearch" -o jsonpath={.items[0].metadata.name}) -- es_util --query="_cluster/pending_tasks"
```

Cluster health
```
oc exec -it -n openshift-logging $(oc get po -n openshift-logging -l "component=elasticsearch" -o jsonpath={.items[0].metadata.name}) -- es_util --query="_cluster/health?pretty"
```

Promethues metric to measure elasticsearch pod's CPU
```
pod:container_cpu_usage:sum{namespace="openshift-logging", pod=~'elasticsearch-cdm-.*'}
```
