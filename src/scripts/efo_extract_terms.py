#!/usr/bin/env python3
"""Keep only the axioms *about* the given EFO terms, ready to merge into efo_cap.owl.

`robot filter --trim false` (run first, on the full efo.owl) keeps every axiom that
mentions a term, including e.g. `child subClassOf term`. This script keeps only the
triples whose subject is a term (following blank nodes such as restrictions), the
owl:Axiom annotations on them, and declarations of the properties they use. That is
what used to be copied by hand from efo.owl.

It also writes a markdown report and fails if a term is missing or obsolete.

usage: efo_extract_terms.py FILTERED_OWL COMPONENT_OWL OUT_OWL REPORT_MD EFO:0000001 [...]
"""
import sys

from rdflib import BNode, Graph, Literal, URIRef
from rdflib.namespace import OWL, RDF, RDFS

EFO = "http://www.ebi.ac.uk/efo/EFO_"
PROPERTY_TYPES = {OWL.AnnotationProperty, OWL.ObjectProperty, OWL.DatatypeProperty}


def to_iri(term):
    return URIRef(EFO + term.replace("EFO:", "").replace("EFO_", ""))


def curie(iri):
    return "EFO:" + str(iri)[len(EFO):] if str(iri).startswith(EFO) else str(iri)


def copy_node(src, dst, node):
    """Copy all triples with this subject, recursing into blank nodes."""
    for p, o in src.predicate_objects(node):
        dst.add((node, p, o))
        if isinstance(o, BNode):
            copy_node(src, dst, o)


def main(filtered, component, out, report, terms):
    src = Graph().parse(filtered)
    comp = Graph().parse(component)
    new = Graph()
    added, skipped, errors = [], [], []

    for term in terms:
        iri = to_iri(term)
        label = src.value(iri, RDFS.label)
        if label is None:
            errors.append(f"{term}: not found in EFO")
        elif src.value(iri, OWL.deprecated) == Literal(True):
            errors.append(f"{term} ({label}): obsolete in EFO")
        elif (iri, RDF.type, OWL.Class) in comp:
            skipped.append(f"{term} ({label}): already in efo_cap.owl")
        else:
            copy_node(src, new, iri)
            for ax in src.subjects(OWL.annotatedSource, iri):
                copy_node(src, new, ax)
            added.append((term, str(label)))

    # declare the properties used, so OWLAPI parses restrictions/annotations correctly
    used = set(new.predicates()) | set(new.objects(None, OWL.onProperty)) | set(new.objects(None, OWL.annotatedProperty))
    for prop in used:
        for t in src.objects(prop, RDF.type):
            if t in PROPERTY_TYPES:
                new.add((prop, RDF.type, t))

    declared = set(comp.subjects(RDF.type, OWL.Class)) | set(new.subjects(RDF.type, OWL.Class))
    missing_parents = sorted(
        {p for p in new.objects(None, RDFS.subClassOf) if isinstance(p, URIRef) and p not in declared}
        | {p for p in new.objects(None, OWL.someValuesFrom) if isinstance(p, URIRef) and p not in declared}
    )

    lines = []
    if added:
        lines += ["Added to `src/ontology/components/efo_cap.owl`:", ""]
        lines += [f"- {t} ({l})" for t, l in added] + [""]
    if skipped:
        lines += ["Skipped:", ""] + [f"- {s}" for s in skipped] + [""]
    if errors:
        lines += ["Errors:", ""] + [f"- {e}" for e in errors] + [""]
    if missing_parents:
        lines += ["Referenced but not declared in the component (check whether they are needed):", ""]
        lines += [f"- [{curie(p)}](https://www.ebi.ac.uk/ols4/search?q={curie(p)})" for p in missing_parents] + [""]
    with open(report, "w") as f:
        f.write("\n".join(lines))
    print("\n".join(lines))

    if errors:
        sys.exit(1)
    if not added:
        sys.exit("No new terms to add.")
    new.serialize(out, format="xml")


if __name__ == "__main__":
    if len(sys.argv) < 6:
        sys.exit(__doc__)
    main(*sys.argv[1:5], sys.argv[5:])
