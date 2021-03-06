# JSON Schema Example

[![Build Status](https://travis-ci.com/pactflow/pactflow-jsonschema-example.svg?branch=master)](https://travis-ci.com/pactflow/pactflow-jsonschema-example)

This example shows how you could share a JSON Schema document with the Pact Broker as a substitute for a Pact contract, and validate that the contract is valid by a provider using the same workflows you would with a standard Pact test.

It's based on the CI/CD workshop from https://docs.pactflow.io/docs/workshops/ci-cd/.

It is using a public tenant on Pactflow, which you can access [here](https://test.pact.dius.com.au) using the credentials `dXfltyFMgNOFZAxr8io9wJ37iUpY42M`/`O5AIZWxelWbLvqMd8PkAVycBJh2Psyg1`.

## Prerequisites

* Docker
* NodeJS 10+
* jq

## Setup

```
npm i
```

## Consumer Test

This phase is analogous to the Pact unit testing phase, where the consumers' client code is tested and as an output produces a contract.

In the case of a JSON schema, this may be through static generation (e.g. using tools such as https://github.com/YousefED/typescript-json-schema), a recording proxy or otherwise.

To emulate a "CI" process, you can run:

```
make fake_ci_consumer
```

This will:

1. Generate the contract (using the TS -> schema generation)
2. Publish the contract to Pactflow (any valid JSON file, so long as it has the `consumer` and `provider` properties, will be accepted by the broker CLI tooling)
3. Run the `can-i-deploy` check (first time, this should fail)
4. If successful, "deploy" to production and tag the application version as moved to `prod`

## Provider Test

Uses https://www.npmjs.com/package/json-schema-diff to do a diff on the JSON schema to check for backwards incompatible contract changes.

```
make fake_ci_provider
```

This will:

1. Fetch the contract (currently it specifically fetches the exact consumer, but it should really use the ["pacts for verification"](https://github.com/pact-foundation/pact_broker/issues/307) endpoint in a real implementation)
1. Extract the schema from the interaction and perform a semantic diff using `json-schema-diff`.
1. Generate a schema from it's local type (`provider/product.ts`)
1. Compare the downloaded schema to the golden schema (`provider/schema/schema.json`) - they must be identical
1. Compare the downloaded schema to the golden schema (`provider/schema/schema.json`) - the downloaded schema (contract) must be _compatible_ with the golden schema
1. Send the verification results back to Pactflow
1. Run the `can-i-deploy` check
1. If successful, "deploy" to production and tag the application version as moved to `prod`

## Running the Provider


```
npm run build
npm start
curl localhost:3000 | jq .
  # will produce:
  #
  # {
  #   "item": "pancakes",
  #   "price": 27.4
  # }
```
