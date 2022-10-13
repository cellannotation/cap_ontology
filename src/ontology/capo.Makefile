## Customize Makefile settings for capo
## 
## If you need to customize your Makefile, make
## changes here rather than in the main Makefile


$(IMPORTDIR)/efo_import.owl: $(MIRRORDIR)/efo.owl $(IMPORTDIR)/efo_terms_combined.txt
	if [ $(IMP) = true ]; then $(ROBOT) merge -i $< \
		query --update ../sparql/preprocess-module.ru \
		extract --method MIREOT -B $(IMPORTDIR)/efo_terms_combined.txt \
		query --update ../sparql/inject-subset-declaration.ru --update ../sparql/inject-synonymtype-declaration.ru --update ../sparql/postprocess-module.ru \
		annotate --ontology-iri $(ONTBASE)/$@ $(ANNOTATE_ONTOLOGY_VERSION) --output $@.tmp.owl && mv $@.tmp.owl $@; fi
		