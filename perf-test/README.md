
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
oc exec -it $(oc get po -l "component=elasticsearch" -o jsonpath={.items[0].metadata.name}) -- es_util --query="_cat/indices"
```


Query 3 last documents of an index
```
export Q_INDEX="app-000001"
echo '{
    "size": 3,
    "sort": { "@timestamp": "desc"},
    "query": {
        "match_all": {}
    }
}' | oc exec -i $(oc get po -l "component=elasticsearch" -o name | head -n1) -- es_util --query="$Q_INDEX/_search" -d @- | jq .
```
