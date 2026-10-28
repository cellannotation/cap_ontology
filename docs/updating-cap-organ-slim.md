# Updating the CAP organ slim

The CAP organ slim is the set of UBERON (and a few CL) terms that CAP uses as
top-level tissue/organ groups. Any tissue annotated in CAP is grouped under the
slim terms it is a descendant of (via `is_a` / `part_of`). A tissue that has no
slim ancestor ends up in **"Other tissues"**.

The slim is maintained as a [ROBOT template](https://robot.obolibrary.org/template):

| File | Role | Edit by hand? |
|---|---|---|
| [`src/templates/cap_organ_slim.tsv`](../src/templates/cap_organ_slim.tsv) | Source of truth: one row per slim term | **Yes** |
| [`src/ontology/components/cap_organ_slim.owl`](../src/ontology/components/cap_organ_slim.owl) | Component generated from the TSV, imported by `capo-edit.owl` | No, regenerate it |
| `capo.owl`, `capo-full.*`, `capo-base.*`, `capo-simple.*`, `capo.obo`, `capo.json` (repo root) | Release artefacts consumed by CAP | No, regenerate them |

**Editing the TSV alone does not change the ontology.** CAP only sees a
change once the component has been regenerated and a release has been made.
For example, PRs [#18](https://github.com/kharchenkolab/cap_ontology/pull/18)
and [#19](https://github.com/kharchenkolab/cap_ontology/pull/19) updated the
TSV but did not run the release. The new terms (e.g. *central nervous system*,
*muscle organ*, *respiratory airway*) are therefore missing from
`components/cap_organ_slim.owl` and from `capo.owl` until a release is run.

An update therefore takes **two PRs**:

1. **Template PR**: edit the TSV only. Anyone can open it; reviewers check the
   terms.
2. **Release PR**: a maintainer regenerates the component and release
   artefacts from `main` after the template PR is merged.

---

## When to edit the template

Add a term when:

- A tissue used in CAP falls into "Other tissues" and there is a sensible
  organ/system-level UBERON ancestor that should be a group of its own. For
  example, #18 added *central nervous system* so that *cranial nerve II*
  stops falling into "Other tissues".
- A new organ or system needs to show up as its own group in CAP.

Before adding a term, check whether an existing slim term already covers the
tissue through its ancestors (use [OLS](https://www.ebi.ac.uk/ols4/ontologies/uberon)
or the UBERON hierarchy). If it does, you don't need a new row. Writing the
coverage down in the PR description, as #19 did, makes review easier:

| Tissue | Covered by |
|---|---|
| common bile duct | UBERON:0001174 → UBERON:0003703 → UBERON:0002394 (bile duct) |
| bronchus | UBERON:0002185 → UBERON:0000117 (respiratory tube) |

Remove or replace a term only after discussion in an issue. Removing a term
changes how existing CAP datasets are grouped.

Do **not** edit the template for:

- Changes to the UBERON/CL terms themselves (labels, hierarchy). Raise those
  upstream in [UBERON](https://github.com/obophenotype/uberon/issues) or
  [CL](https://github.com/obophenotype/cell-ontology/issues).
- EFO-derived terms. Those live in `components/efo_cap.owl`.

## How to edit the template

The file is tab-separated. The first two rows are the ROBOT header and must not
be changed:

```
ID	subset	label
ID	AI oboInOwl:inSubset
```

Each following row is one slim term:

```
UBERON:0001017	http://purl.obolibrary.org/obo/uberon#cap_organ_slim	central nervous system
```

- **ID**: the CURIE of an existing UBERON (or CL) term, e.g. `UBERON:0001017`.
  Check that it exists and is not obsolete.
- **subset**: always exactly `http://purl.obolibrary.org/obo/uberon#cap_organ_slim`.
- **label**: the term's current label in UBERON/CL. ROBOT does not use it to build
  the component; it is there so people can read the file. Keep it in sync with
  the term's label.

Checklist:

- Use tabs, not spaces, and keep the trailing newline.
- Don't add a row that is already there. Search the file for the ID first.
- Keep rows roughly alphabetical by label so the diff stays easy to review.
- Change **only** `src/templates/cap_organ_slim.tsv` in this PR. Don't commit a
  regenerated component or release files here.

Open the PR against `main`. List the terms you added or removed and the reason
for each (which CAP tissues they cover).

## How to make the release (separate PR)

Do this after the template PR has been merged. It needs
[Docker](https://www.docker.com/get-docker); `run.sh` runs the ODK image
(`obolibrary/odkfull`).

```sh
git checkout main
git pull
git checkout -b release-YYYY-MM-DD

cd src/ontology

# 1. Regenerate components/cap_organ_slim.owl from the TSV
#    (the `templates` target is defined in capo.Makefile)
sh run.sh make templates

# 2. Build and copy all release artefacts to the repository root
sh run.sh make prepare_release
```

`prepare_release` does **not** regenerate the component from the TSV by itself.
It only uses whatever is already in `components/cap_organ_slim.owl`. Step 1 is
required.

Check the result before committing:

```sh
cd ../..
git status       # expect: src/ontology/components/cap_organ_slim.owl and the capo*.{owl,obo,json} files
git diff --stat

# each new ID should now appear in the component and the release
grep -c "UBERON_0001017" src/ontology/components/cap_organ_slim.owl capo.owl

# versionIRI/versionInfo should carry today's date
grep -m2 "version" capo.owl
```

Commit the component together with the release artefacts and open the release
PR:

```sh
git add src/ontology/components/cap_organ_slim.owl capo*.owl capo*.obo capo*.json
git commit -m "Release YYYY-MM-DD: regenerate cap_organ_slim component"
git push -u origin release-YYYY-MM-DD
```

In the PR description, link the template PR(s) included in the release
(e.g. "Releases #18, #19").

After the release PR is merged, create a GitHub release from `main`:

- Tag: `vYYYY-MM-DD`. The lowercase `v` is required, and the date must match
  the `versionInfo` in `capo.owl`.
- Title: `YYYY-MM-DD`.
- Release notes: the slim terms that were added or removed.

Make no more than one release per day. See the "Release Manager notes" in
[`src/ontology/README-editors.md`](../src/ontology/README-editors.md) for more detail.

## Summary

| Step | Who | Files changed | Command |
|---|---|---|---|
| Template PR | Anyone | `src/templates/cap_organ_slim.tsv` | none |
| Release PR | Maintainer | `components/cap_organ_slim.owl` + root `capo*` files | `sh run.sh make templates` then `sh run.sh make prepare_release` |
| GitHub release | Maintainer | none (tag `vYYYY-MM-DD`) | none |
