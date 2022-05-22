#!/bin/sh
sleep 120
jq -n --arg pass "`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`" '{"pass": $pass}'
