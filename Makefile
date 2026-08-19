EMACS ?= emacs

EL_FILES  := tjp-mode.el tjp-evil.el
ELC_FILES := $(EL_FILES:.el=.elc)

.PHONY: all compile lint clean

all: compile

compile: $(ELC_FILES)

%.elc: %.el
	$(EMACS) --batch -L . \
	  --eval "(setq byte-compile-error-on-warn t)" \
	  -f batch-byte-compile $<

lint:
	@for f in $(EL_FILES); do \
	  echo "Checking $$f..."; \
	  $(EMACS) --batch -L . -l $$f \
	    --eval "(checkdoc-file \"$$f\")" 2>&1 || true; \
	done

clean:
	rm -f *.elc
