# Adding assay terms

CAP's assay terms are [EFO](https://www.ebi.ac.uk/efo/) classes kept in
[`src/ontology/components/efo_cap.owl`](../src/ontology/components/efo_cap.owl).
That component is imported by `capo-edit.owl` and included in every release.

| File | Role | Edit by hand? |
|---|---|---|
| `src/ontology/components/efo_cap.owl` | EFO assay classes, copied from EFO with all their axioms | No, use the issue form or `make add-efo-terms` |
| `capo.owl`, `capo-full.*`, `capo-base.*`, `capo-simple.*`, `capo.obo`, `capo.json` (repo root) | Release artefacts consumed by CAP | No, regenerate them |

**Adding a term to `efo_cap.owl` does not change the release.** CAP only sees
the term after the [release step](#release-step-after-adding-terms).

### Used by the CAP pipeline

Each assay term is tagged
`oboInOwl:inSubset <http://purl.obolibrary.org/obo/capo#cap_assay>`. The CAP
pipeline ([cap-pipeline-config](https://github.com/cellannotation/cap-pipeline-config))
loads `capo-base.owl` from `main`. Its
`config/dumps/sparql/construct_Assay.sparql` labels every term in that subset
as an Assay, the same way `construct_Organ.sparql` uses an organ subset.

- Nothing needs editing in cap-pipeline-config when you add an assay. The tag
  is added automatically by the issue form and by `make add-efo-terms`.
- A new assay reaches CAP only after the CAPO release PR is merged into `main`.
- The parent classes in `efo_cap.owl` are not tagged, so they don't become
  Assays.

---

## When to add a term

- A CAP dataset uses an assay that isn't in `efo_cap.owl` yet, e.g. a new 10x
  chemistry (#15, #16).
- The term must **already exist in EFO**. Search
  [OLS](https://www.ebi.ac.uk/ols4/ontologies/efo). If it doesn't exist, request it
  from [EFO](https://github.com/EBISPOT/efo/issues) and wait for an EFO release.
  Don't create EFO IDs in this repo.
- Obsolete EFO terms are rejected. Use the replacement term instead.

## Option 1: issue form (recommended)

1. Open a new issue with the
   [**Add assay term**](https://github.com/cellannotation/cap_ontology/issues/new?template=add-assay-term.yml)
   form. List the EFO IDs one per line (e.g. `EFO:0022604`) and say why they are
   needed.
2. The [Add assay terms](../.github/workflows/add-assay-term.yml) workflow:
   1. downloads the latest EFO release;
   2. copies the terms into `efo_cap.owl`;
   3. runs the QC checks;
   4. opens a PR and links it in an issue comment.

   If GitHub doesn't allow the workflow to open PRs, the comment links a
   **Create pull request** page instead, with the title and description
   already filled in. Click it and submit. This happens when the
   `CAPO_BOT_TOKEN` secret is missing or lacks pull request access, and the
   org doesn't let Actions create PRs.

   If something is wrong, the comment explains it instead (unknown ID, obsolete
   term, already present).
3. Review the PR. The PR description lists:
   - the terms added, with their labels;
   - terms skipped because they are already present;
   - parent classes the new terms refer to that aren't declared in the component.
     That is usually fine: several existing terms are like this. Add a parent too
     only if CAP needs it as an assay of its own.
4. Merge, then do the [release step](#release-step-after-adding-terms).

The workflow runs only for people who can triage issues in this repo. If
someone else opens the issue, a maintainer re-applies the `new-assay-term`
label to start it. Maintainers can also run it from the Actions tab
(**Add assay terms → Run workflow**) with a list of IDs.

## Option 2: locally

Use this when the workflow isn't available, or to try a change first. It needs
[Docker](https://www.docker.com/get-docker) (`run.sh` runs the ODK image).

```sh
git checkout main && git pull
git checkout -b add-assay-terms

cd src/ontology
sh run.sh make add-efo-terms EFO_TERMS="EFO:0022604 EFO:0005684"
sh run.sh make test IMP=false PAT=false
```

- The first run downloads EFO (about 350 MB) to `src/ontology/tmp/efo.owl`.
  Run `sh run.sh make refresh-efo` to get a newer EFO release later.
- The report is printed and saved to `tmp/efo_report.md`; use it for the PR
  description.
- Commit only `src/ontology/components/efo_cap.owl`.

### What the command does

There's no need to copy blocks from `efo.owl` by hand any more. The
`add-efo-terms` target (in `src/ontology/capo.Makefile`) does it in three steps:

1. `robot filter --select self --axioms all --trim false` on the full EFO keeps
   every axiom that mentions the terms. It uses the `http://www.ebi.ac.uk/efo/EFO_`
   prefix, so the IRIs are always right. That was the cause of the namespace fix
   in #15.
2. `src/scripts/efo_extract_terms.py` keeps only the axioms whose subject is the
   term: parents, restrictions, label, definition, synonyms, and annotations on
   them. It drops references from other classes, e.g. `child subClassOf term`.
   It tags the term with the `cap_assay` subset. It also checks that each term exists, isn't obsolete and isn't already present,
   and writes the report.
3. `robot merge` adds the result to `efo_cap.owl`.

The result is the same as copying the block by hand. For example, re-adding
EFO:0005684 this way gives exactly what #17 added.

ROBOT re-serializes `efo_cap.owl`, so a PR may also move a few
`hasRelatedSynonym` lines within EFO:0009899, EFO:0009901 and EFO:0009922. Their
values differ only in case (`10X 3' v2 sequencing` vs `10x 3' v2 sequencing`), so
their order isn't stable. This is harmless.

## Release step after adding terms

Do this in a **separate PR** after the term PR(s) are merged. Several term PRs
can go into one release.

```sh
git checkout main && git pull
git checkout -b release-YYYY-MM-DD

cd src/ontology
sh run.sh make templates          # also regenerates the organ slim from its TSV
sh run.sh make prepare_release
```

Before committing, confirm that the new terms are in the release:

```sh
cd ../..
grep -c "EFO_0022604" capo.owl
grep -m2 "version" capo.owl    # today's date
```

Commit the root `capo*` files (and `components/cap_organ_slim.owl` if it
changed), and open the release PR. After merging, create the GitHub release
with tag `vYYYY-MM-DD`. The full steps are in
[Updating the CAP organ slim: How to make the release](updating-cap-organ-slim.md#how-to-make-the-release-separate-pr).

`prepare_release` publishes everything on `main`, including unreleased
organ slim changes. That's why `make templates` runs first.

## Summary

| Step | Who | Files changed | How |
|---|---|---|---|
| Term PR | Anyone (issue form) or maintainer (local) | `src/ontology/components/efo_cap.owl` | Issue form, or `sh run.sh make add-efo-terms EFO_TERMS="…"` |
| Release PR | Maintainer | root `capo*` files | `sh run.sh make templates` then `sh run.sh make prepare_release` |
| GitHub release | Maintainer | none (tag `vYYYY-MM-DD`) | none |
