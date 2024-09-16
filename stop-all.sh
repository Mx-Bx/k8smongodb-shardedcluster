#!/bin/bash

kubectl delete statefulsets,deployments --all
kubectl delete pods --all
kubectl delete services --all

kubectl delete pvc --all
#kubectl delete pv --all


kubectl get all
kubectl get pvc
#kubectl get pv