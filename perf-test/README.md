
```
oc create ns myapp
oc project myapp
oc process -f ./perf-test/app-python.yaml -n myapp | oc apply -n myapp -f -
```

```
oc project openshift-logging
oc apply -f ./perf-test/logforwarder.yaml
```

```
oc exec -it $(oc get po -l "component=elasticsearch" -o name | head -n1) -- es_util --query="_cat/indices"
```
