PYTESTS = $(wildcard test/test_*.py)

.PHONY: all
all:
	@$(MAKE) usage | less

# Display usage for all make targets
.PHONY: usage
usage:
	@echo
	@echo 'make TARGET [option=value, ...]'
	@echo
	@echo 'TESTING'
	@echo
	@echo '  make test [testargs=ARGS]'
	@echo '    - Run all tests. "testargs" can specify a single string of arguments'
	@echo '      for py.test.'
	@echo
	@echo '  make <testfile>.py [testargs=ARGS]'
	@echo '    - Run tests from a specific test file. "testargs" can specify a'
	@echo '      single string of arguments for py.test.'
	@echo
	@echo '  make testhost [version=VERSION]'
	@echo '    - Create an ephemeral container for doing adhoc yadm testing. The'
	@echo '      HEAD revision of yadm will be used unless "version" is'
	@echo '      specified. "version" can be set to any commit, branch, tag, etc.'
	@echo '      The targeted "version" will be retrieved from the repo, and'
	@echo '      linked into the container as a local volume.'
	@echo
	@echo 'LINTING'
	@echo
	@echo '  make testenv'
	@echo '    - Create a python virtual environment with the dependencies used'
	@echo "      by yadm's testbed environment. Creating and activating this"
	@echo '      environment might be useful if your editor does real time'
	@echo '      linting of python files. After creating the virtual environment,'
	@echo '      you can activate it by typing'
	@echo
	@echo 'MANPAGES'
	@echo
	@echo '  make man'
	@echo '    - View yadm.1 as a standard manpage.'
	@echo
	@echo '  make man-wide'
	@echo '    - View yadm.1 as a manpage, using all columns of your display.'
	@echo
	@echo '  make man-ps'
	@echo '    - Create a postscript version of the manpage.'
	@echo
	@echo 'FILE GENERATION'
	@echo
	@echo '  make yadm.md'
	@echo '    - Generate the markdown version of the manpage (for viewing on'
	@echo '      the web).'
	@echo
	@echo '  make contrib'
	@echo '    - Generate the CONTRIBUTORS file, from the repo history.'
	@echo
	@echo 'UTILITIES'
	@echo
	@echo '  make sync-clock'
	@echo '    - Reset the hardware clock for the docker hypervisor host. This'
	@echo '      can be useful for docker engine hosts which are not'
	@echo '      Linux-based.'
	@echo

# Make it possible to run make specifying a py.test test file
.PHONY: $(PYTESTS)
$(PYTESTS):
	@$(MAKE) test testargs="-k $@ $(testargs)"
%.py:
	@$(MAKE) test testargs="-k $@ $(testargs)"

# Run all tests with additional testargs
.PHONY: test
test:
	@if [ -f /.yadmtestbed ]; then \
		cd /yadm && \
		py.test -v $(testargs); \
	else \
		if command -v "docker-compose" >/dev/null 2>&1; then \
			docker-compose run --rm testbed make test testargs="$(testargs)"; \
		else \
			echo "Sorry, this make test requires docker-compose to be installed."; \
			false; \
		fi \
	fi

.PHONY: testhost
testhost:
	@if ! command -v "docker" >/dev/null 2>&1; then \
		echo "Sorry, this make target requires docker to be installed."; \
		false; \
	fi
	@version=HEAD
	@rm -rf /tmp/testhost
	@git show $(version):yadm > /tmp/testhost
	@chmod a+x /tmp/testhost
	@echo Starting testhost version=\"$$version\"
	@docker run -w /root --hostname testhost --rm -it -v "/tmp/testhost:/bin/yadm:ro" yadm/testbed:latest bash -l

.PHONY: testenv
testenv:
	@echo 'Creating a local virtual environment in "testenv/"'
	@echo
	virtualenv --python=python3 testenv
	testenv/bin/pip3 install --upgrade pip setuptools
	testenv/bin/pip3 install --upgrade pytest pylint==1.9.2 flake8==3.5.0
	@echo
	@echo 'To activate this test environment type:'
	@echo '  source testenv/bin/activate'

.PHONY: man
man:
	@groff -man -Tascii ./yadm.1 | less

.PHONY: man-wide
man-wide:
	@man ./yadm.1

.PHONY: man-ps
man-ps:
	@groff -man -Tps ./yadm.1 > yadm.ps

yadm.md: yadm.1
	@groff -man -Tascii ./yadm.1 | col -bx | sed 's/^[A-Z]/## &/g' | sed '/yadm(1)/d' > yadm.md

.PHONY: contrib
contrib:
	@echo "CONTRIBUTORS\n" > CONTRIBUTORS
	@git shortlog -ns master gh-pages dev dev-pages | cut -f2 >> CONTRIBUTORS

.PHONY: sync-clock
sync-clock:
	docker run --rm --privileged alpine hwclock -s
