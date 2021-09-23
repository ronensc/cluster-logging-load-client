
Deploy 1st app
```
oc create ns myapp
oc project myapp
oc process -f ./perf-test/app-python.yaml -n myapp | oc apply -n myapp -f -
```


Deploy 2nd app
```
oc create ns myapp2
oc project myapp2
oc process -f ./perf-test/app-python.yaml -n myapp2 | oc apply -n myapp2 -f -
```

```
oc project openshift-logging
oc apply -f ./perf-test/logforwarder.yaml
```

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
