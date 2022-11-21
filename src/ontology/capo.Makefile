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

