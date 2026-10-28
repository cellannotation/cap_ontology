## Customize Makefile settings for capo
## 
## If you need to customize your Makefile, make
## changes here rather than in the main Makefile

TEMPLATESDIR = ../templates

TEMPLATES=$(patsubst %.tsv, $(TEMPLATESDIR)/%.owl, $(notdir $(wildcard $(TEMPLATESDIR)/*.tsv)))

.PHONY: templates
templates: $(TEMPLATES)

$(TEMPLATESDIR)/%.owl: $(TEMPLATESDIR)/%.tsv $(SRC)
	$(ROBOT) -vvv merge -i $(SRC) template --template $< --output $(COMPONENTSDIR)/$*.owl && \
	$(ROBOT) -vvv annotate --input $(COMPONENTSDIR)/$*.owl --ontology-iri $(ONTBASE)/components/$*.owl -o $(COMPONENTSDIR)/$*.owl

# ----------------------------------------
# Assay terms (EFO component)
# ----------------------------------------
# Copies EFO classes, with all their axioms, into components/efo_cap.owl.
# usage: sh run.sh make add-efo-terms EFO_TERMS="EFO:0022604 EFO:0005684"

EFO_URL = http://www.ebi.ac.uk/efo/efo.owl
# EFO IRIs are http://www.ebi.ac.uk/efo/EFO_*, not OBO PURLs
EFO_PREFIX = --prefix "EFO: http://www.ebi.ac.uk/efo/EFO_"
EFO_TERM_IDS = $(subst EFO_,EFO:,$(EFO_TERMS))

$(TMPDIR)/efo.owl: | $(TMPDIR)
	curl -L --fail -o $@ $(EFO_URL)

.PHONY: refresh-efo
refresh-efo:
	rm -f $(TMPDIR)/efo.owl && $(MAKE) $(TMPDIR)/efo.owl

.PHONY: add-efo-terms
add-efo-terms: $(TMPDIR)/efo.owl
	@test -n "$(EFO_TERMS)" || (echo 'usage: make add-efo-terms EFO_TERMS="EFO:0022604 EFO:0005684"' && exit 1)
	$(ROBOT) $(EFO_PREFIX) filter -i $< $(foreach t,$(EFO_TERM_IDS),--term $(t)) \
		--select self --axioms all --trim false --signature false -o $(TMPDIR)/efo_filtered.owl
	python3 ../scripts/efo_extract_terms.py $(TMPDIR)/efo_filtered.owl $(COMPONENTSDIR)/efo_cap.owl \
		$(TMPDIR)/efo_new.owl $(TMPDIR)/efo_report.md $(EFO_TERM_IDS)
	$(ROBOT) merge -i $(COMPONENTSDIR)/efo_cap.owl -i $(TMPDIR)/efo_new.owl -o $(COMPONENTSDIR)/efo_cap.owl

