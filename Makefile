all: build

################################################################################
##                                   DEP                                      ##
################################################################################
DEP ?= ./dep
DEP_VER ?= 0.3.2
DEP_BIN := dep-$$GOHOSTOS-$$GOHOSTARCH
DEP_URL := https://github.com/golang/dep/releases/download/v$(DEP_VER)/$$DEP_BIN

$(DEP):
	GOVERSION=$$(go version | awk '{print $$4}') && \
	GOHOSTOS=$$(echo $$GOVERSION | awk -F/ '{print $$1}') && \
	GOHOSTARCH=$$(echo $$GOVERSION | awk -F/ '{print $$2}') && \
	DEP_BIN="$(DEP_BIN)" && \
	DEP_URL="$(DEP_URL)" && \
	curl -sSLO $$DEP_URL && \
	chmod 0755 "$$DEP_BIN" && \
	mv -f "$$DEP_BIN" "$@"

ifneq (./dep,$(DEP))
dep: $(DEP)
endif

dep-ensure: | $(DEP)
	$(DEP) ensure -v


########################################################################
##                               CSI SPEC                             ##
########################################################################
CSI_SPEC :=  vendor/github.com/container-storage-interface/spec
CSI_GOSRC := $(CSI_SPEC)/lib/go/csi/csi.pb.go


########################################################################
##                               GOCSI                                ##
########################################################################
GOCSI_A := gocsi.a
$(GOCSI_A): $(CSI_GOSRC) *.go
	@go install .
	go build -o "$@" .


########################################################################
##                               TEST                                 ##
########################################################################
GINKGO := ./ginkgo
GINKGO_PKG := ./vendor/github.com/onsi/ginkgo/ginkgo
GINKGO_SECS := 20
ifeq (true,$(TRAVIS))
GINKGO_SECS := 30
endif
GINKGO_RUN_OPTS := --slowSpecThreshold=$(GINKGO_SECS) -randomizeAllSpecs -p
$(GINKGO):
	go build -o "$@" $(GINKGO_PKG)

# The test recipe executes the Go tests with the Ginkgo test
# runner. This is the reason for the boolean OR condition
# that is part of the test script. The condition allows for
# the test run to exit with a status set to the value Ginkgo
# uses if it detects programmatic involvement. Please see
# https://goo.gl/CKz4La for more information.
ifneq (true,$(TRAVIS))
test:  build
endif

# Because Travis-CI's containers have limited resources, the Mock SP's
# idempotency provider's timeout needs to be increased from the default
# value of 0 to 1s. This ensures that lack of system resources will not
# prevent a single, non-concurrent RPC from failing due to an OpPending
# error.
ifeq (true,$(TRAVIS))
export X_CSI_IDEMP_TIMEOUT=1s
endif

test: | $(GINKGO)
	$(GINKGO) $(GINKGO_RUN_OPTS) . || test "$$?" -eq "197"


########################################################################
##                               BENCH                                ##
########################################################################
ifneq (true,$(TRAVIS))
bench: build
endif
bench:
	go test -run Bench -bench . -benchmem . || test "$$?" -eq "197"


########################################################################
##                               BUILD                                ##
########################################################################

build: $(GOCSI_A)
	$(MAKE) -C csc $@
	$(MAKE) -C mock $@

clean:
	go clean -i -v . ./csp
	rm -f "$(GOCSI_A)"
	$(MAKE) -C csc $@
	$(MAKE) -C mock $@

clobber: clean
	$(MAKE) -C csc $@
	$(MAKE) -C mock $@

.PHONY: build test bench clean clobber
