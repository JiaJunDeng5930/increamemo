ELDEV ?= eldev

.PHONY: bootstrap compile lint test package check precommit ci clean doctor

bootstrap:
	$(ELDEV) prepare

compile:
	$(ELDEV) compile

lint:
	$(ELDEV) lint

test:
	$(ELDEV) test

package:
	$(ELDEV) package

check: compile lint test package

precommit: compile lint test

ci: check
	pre-commit run --all-files

doctor:
	$(ELDEV) doctor

clean:
	$(ELDEV) clean all
