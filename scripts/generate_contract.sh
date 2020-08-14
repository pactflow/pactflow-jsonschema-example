#!/bin/sh
PACT_FILE="${PWD}/consumer/pacts/schema-consumer_schema-provider.json"
TEMPLATE_SCHEMA="${PWD}/pact-template.json"

mkdir -p consumer/pacts
BODY=$(./node_modules/.bin/typescript-json-schema "consumer/*.ts" "*")
cat ${TEMPLATE_SCHEMA} | jq ".schema += ${BODY}" > ${PACT_FILE}