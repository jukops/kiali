#
# Targets to run operator molecule tests.
#

# The test scenario(s) to run - see molecule/ - all directories with a name *-test are scenarios you can run
# Example: MOLECULE_SCENARIO=token-test make molecule-test
# To run multiple scenarios sequentially: MOLECULE_SCENARIO="token-test roles-test" make molecule-test
MOLECULE_SCENARIO ?= default

# Set MOLECULE_USE_DEV_IMAGES to true to use your local Kiali dev builds (not released images from quay.io).
# To use this, you must have first pushed your local Kiali dev builds via the cluster-push target.
# Note that you can use your own image names/versions if you set MOLECULE_IMAGE_ENV_ARGS appropriately.
# This is useful if you want to test a specific released version or images found in a different repo.
# If the x_IMAGE_NAME env vars are set to 'dev' then the molecule tests will use the internal OpenShift registry location.
ifeq ($(MOLECULE_USE_DEV_IMAGES),true)
ifeq ($(CLUSTER_TYPE),openshift)
MOLECULE_IMAGE_ENV_ARGS = --env MOLECULE_KIALI_OPERATOR_IMAGE_NAME=dev --env MOLECULE_KIALI_OPERATOR_IMAGE_VERSION=dev --env MOLECULE_KIALI_IMAGE_NAME=dev --env MOLECULE_KIALI_IMAGE_VERSION=dev
else ifeq ($(CLUSTER_TYPE),minikube)
MOLECULE_IMAGE_ENV_ARGS = --env MOLECULE_KIALI_OPERATOR_IMAGE_NAME=localhost:5000/kiali/kiali-operator --env MOLECULE_KIALI_OPERATOR_IMAGE_VERSION=dev --env MOLECULE_KIALI_IMAGE_NAME=localhost:5000/kiali/kiali --env MOLECULE_KIALI_IMAGE_VERSION=dev
endif
endif

ifeq ($(MOLECULE_DEBUG),true)
MOLECULE_DEBUG_ARG = --debug
endif

ifeq ($(MOLECULE_DESTROY_NEVER),true)
MOLECULE_DESTROY_NEVER_ARG = --destroy never
endif

MOLECULE_KUBECONFIG ?= ${HOME}/.kube/config

# Set up some additional things needed in order to run the molecule tests against a minikube installation
ifeq ($(CLUSTER_TYPE),minikube)
MOLECULE_MINIKUBE_DIR ?= ${HOME}/.minikube
MOLECULE_MINIKUBE_VOL_ARG = -v ${MOLECULE_MINIKUBE_DIR}:${MOLECULE_MINIKUBE_DIR}
MOLECULE_MINIKUBE_IP ?= $(shell ${MINIKUBE} ip -p ${MINIKUBE_PROFILE})
MOLECULE_MINIKUBE_ENV_ARGS ?= --env MOLECULE_MINIKUBE_IP=$(shell echo -n ${MOLECULE_MINIKUBE_IP})
# if there are no hosts the user wants, explicitly set this to empty string to avoid errors later
ifndef MOLECULE_ADD_HOST_ARGS
MOLECULE_ADD_HOST_ARGS =
endif
endif

## molecule-build: Builds an image to run Molecule without requiring the host to have python/pip installed
molecule-build: .ensure-operator-repo-exists
ifeq ($(DORP),docker)
	docker build -t kiali-molecule:latest ${ROOTDIR}/operator/molecule/docker
else
	podman build -t kiali-molecule:latest ${ROOTDIR}/operator/molecule/docker
endif

ifndef MOLECULE_ADD_HOST_ARGS
.prepare-add-host-args: .prepare-cluster
	@$(eval MOLECULE_ADD_HOST_ARGS ?= $(shell basehost="$(shell echo ${CLUSTER_REPO} | sed 's/^.*\.apps\.\(.*\)/\1/')"; kialihost="kiali-istio-system.apps.$${basehost}"; kialiip="$$(getent hosts $${kialihost} | awk '{ print $$1 }')"; prometheushost="prometheus-istio-system.apps.$${basehost}"; prometheusip="$$(getent hosts $${prometheushost} | awk '{ print $$1 }')" apihost="api.$${basehost}"; apiip="$$(getent hosts $${apihost} | awk '{ print $$1 }')"; echo "--add-host=$$kialihost:$$kialiip --add-host=$$prometheushost:$$prometheusip --add-host=$$apihost:$$apiip"))
else
.prepare-add-host-args:
	@echo "Will use the given add host args: ${MOLECULE_ADD_HOST_ARGS}"
endif

## molecule-test: Runs Molecule tests using the Molecule docker image
molecule-test: .ensure-operator-repo-exists .prepare-add-host-args
ifeq ($(DORP),docker)
	for msn in ${MOLECULE_SCENARIO}; do docker run --rm -it -v "${ROOTDIR}/operator":/tmp/$(basename "${ROOTDIR}/operator"):ro -v "${MOLECULE_KUBECONFIG}":/root/.kube/config:ro -v /var/run/docker.sock:/var/run/docker.sock ${MOLECULE_MINIKUBE_VOL_ARG} ${MOLECULE_MINIKUBE_ENV_ARGS} -w /tmp/$(basename "${ROOTDIR}/operator") --network="host" ${MOLECULE_ADD_HOST_ARGS} --add-host="api.crc.testing:192.168.130.11" --add-host="kiali-istio-system.apps-crc.testing:192.168.130.11" --add-host="prometheus-istio-system.apps-crc.testing:192.168.130.11" ${MOLECULE_IMAGE_ENV_ARGS} kiali-molecule:latest molecule ${MOLECULE_DEBUG_ARG} test ${MOLECULE_DESTROY_NEVER_ARG} --scenario-name $${msn}; if [ "$$?" != "0" ]; then echo "Molecule test failed: $${msn}"; exit 1; fi; done
else
	for msn in ${MOLECULE_SCENARIO}; do podman run --rm -it -v "${ROOTDIR}/operator":/tmp/$(basename "${ROOTDIR}/operator"):ro -v "${MOLECULE_KUBECONFIG}":/root/.kube/config:ro -v /var/run/docker.sock:/var/run/docker.sock ${MOLECULE_MINIKUBE_VOL_ARG} ${MOLECULE_MINIKUBE_ENV_ARGS} -w /tmp/$(basename "${ROOTDIR}/operator") --network="host" ${MOLECULE_ADD_HOST_ARGS} --add-host="api.crc.testing:192.168.130.11" --add-host="kiali-istio-system.apps-crc.testing:192.168.130.11" --add-host="prometheus-istio-system.apps-crc.testing:192.168.130.11" ${MOLECULE_IMAGE_ENV_ARGS} kiali-molecule:latest molecule ${MOLECULE_DEBUG_ARG} test ${MOLECULE_DESTROY_NEVER_ARG} --scenario-name $${msn}; if [ "$$?" != "0" ]; then echo "Molecule test failed: $${msn}"; exit 1; fi; done
endif

## molecule-test-all: Runs all Molecule tests using the Molecule docker image
molecule-test-all: .ensure-operator-repo-exists .prepare-add-host-args
ifeq ($(DORP),docker)
	docker run --rm -it -v "${ROOTDIR}/operator":/tmp/$(basename "${ROOTDIR}/operator"):ro -v "${MOLECULE_KUBECONFIG}":/root/.kube/config:ro -v /var/run/docker.sock:/var/run/docker.sock ${MOLECULE_MINIKUBE_VOL_ARG} ${MOLECULE_MINIKUBE_ENV_ARGS} -w /tmp/$(basename "${ROOTDIR}/operator") --network="host" ${MOLECULE_ADD_HOST_ARGS} --add-host="api.crc.testing:192.168.130.11" --add-host="kiali-istio-system.apps-crc.testing:192.168.130.11" --add-host="prometheus-istio-system.apps-crc.testing:192.168.130.11" ${MOLECULE_IMAGE_ENV_ARGS} kiali-molecule:latest molecule ${MOLECULE_DEBUG_ARG} test ${MOLECULE_DESTROY_NEVER_ARG} --all
else
	podman run --rm -it -v "${ROOTDIR}/operator":/tmp/$(basename "${ROOTDIR}/operator"):ro -v "${MOLECULE_KUBECONFIG}":/root/.kube/config:ro -v /var/run/docker.sock:/var/run/docker.sock ${MOLECULE_MINIKUBE_VOL_ARG} ${MOLECULE_MINIKUBE_ENV_ARGS} -w /tmp/$(basename "${ROOTDIR}/operator") --network="host" ${MOLECULE_ADD_HOST_ARGS} --add-host="api.crc.testing:192.168.130.11" --add-host="kiali-istio-system.apps-crc.testing:192.168.130.11" --add-host="prometheus-istio-system.apps-crc.testing:192.168.130.11" ${MOLECULE_IMAGE_ENV_ARGS} kiali-molecule:latest molecule ${MOLECULE_DEBUG_ARG} test ${MOLECULE_DESTROY_NEVER_ARG} --all
endif
