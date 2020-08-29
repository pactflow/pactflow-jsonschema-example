# Default to the read only token - the read/write token will be present on Travis CI.
# It's set as a secure environment variable in the .travis.yml file
PACTICIPANT := "example-jsonschema-consumer"
PROVIDER := "example-jsonschema-provider"
GITHUB_WEBHOOK_UUID := "04510dc1-7f0a-4ed2-997d-114bfa86f8ad"
PACT_CLI="docker run --rm -v ${PWD}:${PWD} -e PACT_BROKER_BASE_URL -e PACT_BROKER_TOKEN pactfoundation/pact-cli:latest"
PACT_FILE="${PWD}/consumer/pacts/schema-consumer_schema-provider.json"
TEMPLATE_SCHEMA="${PWD}/pact-template.json"
PROVIDER_GOLD_SCHEMA="${PWD}/provider/schema/schema.json"
PROVIDER_GENERATED_SCHEMA="${PWD}/.tmp/provider-generated-schema.json"
DOWNLOADED_RAW_PACT="${PWD}/.tmp/consumer-pact.json"
DOWNLOADED_PACT="${PWD}/.tmp/consumer-schema.json"
DIFF_CLI="./node_modules/.bin/json-schema-diff"
AUTH_HEADER=-H "Authorization: Bearer ${PACT_BROKER_TOKEN}"
CONTENT_TYPE_HEADER=-H 'Content-Type: application/json'

# Only deploy from master
ifeq ($(TRAVIS_BRANCH),master)
	CONSUMER_DEPLOY_TARGET=deploy_consumer
	PROVIDER_DEPLOY_TARGET=deploy_provider
else
	CONSUMER_DEPLOY_TARGET=no_deploy
	PROVIDER_DEPLOY_TARGET=no_deploy
endif

# emulates the travis build
fake_ci:
	TRAVIS_COMMIT=`git rev-parse --short HEAD`+`date "+%m%d%H%M%Y"` \
	TRAVIS_BRANCH=`git rev-parse --abbrev-ref HEAD` \
	./scripts/ci.sh

##
## Consumer side
##
fake_ci_consumer:
	CI=true \
	TRAVIS_COMMIT=`git rev-parse --short HEAD`+`date "+%m%d%H%M%Y"` \
	TRAVIS_BRANCH=`git rev-parse --abbrev-ref HEAD` \
	make ci_consumer

ci_consumer: clean generate_consumer_contract publish_contract can_i_deploy_consumer $(CONSUMER_DEPLOY_TARGET)

generate_consumer_contract:
	@echo "\n==> 🤝 Generating contract from commit: ${TRAVIS_COMMIT}\n"
	@./scripts/generate_consumer_contract.sh

publish_contract:
	@echo "\n==> 📄 Publishing contract\n"
	@"${PACT_CLI}" publish ${PACT_FILE} --consumer-app-version ${TRAVIS_COMMIT} --tag ${TRAVIS_BRANCH}

can_i_deploy_consumer:
	@echo "\n==> ⁉️  check if it's safe to release consumer to prod?\n"
	@"${PACT_CLI}" broker can-i-deploy \
	  --pacticipant ${PACTICIPANT} \
	  --version ${TRAVIS_COMMIT} \
	  --to prod \
	  --retry-while-unknown 0 \
	  --retry-interval 10

deploy_consumer: deploy tag_consumer_as_prod

tag_consumer_as_prod:
	@echo "\n🏷  Tagging consumer as deployed to 'prod'\n"
	@"${PACT_CLI}" broker create-version-tag --pacticipant ${PACTICIPANT} --version ${TRAVIS_COMMIT} --tag prod

##
## Provider side
##
fake_ci_provider:
	CI=true \
	TRAVIS_COMMIT=`git rev-parse --short HEAD`+`date +%s` \
	TRAVIS_BRANCH=`git rev-parse --abbrev-ref HEAD` \
	make ci_provider

ci_provider: clean fetch_contract test can_i_deploy_provider $(PROVIDER_DEPLOY_TARGET)

fetch_contract:
	@echo "\n==> 📄 Downloading contracts from Pactflow\n"
	@curl ${AUTH_HEADER} "${PACT_BROKER_BASE_URL}/pacts/provider/${PROVIDER}/consumer/${PACTICIPANT}/latest/${TRAVIS_BRANCH}" > ${DOWNLOADED_RAW_PACT}
	@cat ${DOWNLOADED_RAW_PACT} | jq .schema > ${DOWNLOADED_PACT}

test:
	@echo "\n==> ✅ Running schema validation\n"
	@./node_modules/.bin/typescript-json-schema --required "provider/product.ts" "ProductAPI.Product" > ${PROVIDER_GENERATED_SCHEMA}
	@RESULTS_URL=$(shell cat ${DOWNLOADED_RAW_PACT} | jq -r '.["_links"]|.["pb:publish-verification-results"].href'); \
	make provider_diff; \
	if [ $$? != 0 ]; then \
		echo "Contract verifications are not compatible, failing"; \
		curl -X POST ${CONTENT_TYPE_HEADER} ${AUTH_HEADER} $$RESULTS_URL -d '{ "success": false, "providerApplicationVersion": "${TRAVIS_COMMIT}" }'; \
		exit 1; \
	else \
		curl -X POST ${CONTENT_TYPE_HEADER} ${AUTH_HEADER} $$RESULTS_URL -d '{ "success": true, "providerApplicationVersion": "${TRAVIS_COMMIT}" }'; \
		echo "Contract verification is complete!"; \
	fi

provider_diff:
	diff -wBb ${PROVIDER_GOLD_SCHEMA} ${PROVIDER_GENERATED_SCHEMA} && ${DIFF_CLI} ${PROVIDER_GOLD_SCHEMA} ${DOWNLOADED_PACT};

deploy_provider: deploy tag_provider_as_prod

can_i_deploy_provider:
	@echo "\n==> ⁉️  check if it's safe to release provider to prod?\n"
	@"${PACT_CLI}" broker can-i-deploy \
	  --pacticipant ${PROVIDER} \
	  --version ${TRAVIS_COMMIT} \
	  --to prod \
	  --retry-while-unknown 0 \
	  --retry-interval 10

tag_provider_as_prod:
	@echo "\n🏷 ==> Tagging provider as deployed to 'prod'\n"
	@"${PACT_CLI}" broker create-version-tag --pacticipant ${PROVIDER} --version ${TRAVIS_COMMIT} --tag prod

##
## Shared tasks
##
no_deploy:
	@echo "\n==> Not deploying as not on master branch\n"

deploy:
	@echo "\n==> 🚀 Deploying to prod\n"

clean:
	@mkdir -p ${PWD}/.tmp
	@mkdir -p consumer/pacts
	-@rm .tmp/*.json consumer/pacts/*.json
