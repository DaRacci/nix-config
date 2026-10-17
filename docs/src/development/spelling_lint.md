# Spelling Lint

Prose in `docs/` and `AGENTS.md` is checked with [Vale], using an Australian
English spelling style. The configuration lives in `.vale.ini` and `ci/vale/`.

## Layout

| Path                                        | Purpose                                             |
| ------------------------------------------- | --------------------------------------------------- |
| `.vale.ini`                                 | selects the linted paths and the `AU-English` style |
| `ci/vale/styles/AU-English/Spelling.yml`    | the spelling rule and the dictionaries it loads     |
| `ci/vale/styles/AU-English/Terms.yml`       | generated: host name and term casing rule           |
| `ci/vale/styles/config/dictionaries/`       | the dictionaries and allow-lists the rules read     |
| `flake/dev/scripts/vale-tech-dictionary.nu` | builds the `tech` dictionary from the cspell lists  |

## Dictionaries

The spelling rule loads two hunspell dictionaries:

- `en_AU-large`, the base wordlist, from `hunspellDicts.en_AU-large`.
- `tech`, ordinary programming vocabulary such as `namespaced`, `attrset` and
  `unmount`. It is built by the `vale-tech-dictionary` derivation from a fixed
  subset of the [cspell] lists.

## Generated And Hand-Written Allow-lists

`install-vale-dictionaries`, a `nu` tool in `flake/dev/scripts/`, installs the dictionaries and writes the generated allow-lists into `ci/vale/styles/`.
The `vale:installDictionaries` devenv task runs it on shell entry, and CI runs it with `nix run .#install-vale-dictionaries`.
Everything it writes is gitignored.

The `vale` git hook runs Vale on every staged Markdown file, so `docs/` and `AGENTS.md` are checked before the commit is made.
It needs the dictionaries in place, which the shell entry task provides.

It derives `terms.txt` from the repository: every host, every package under
`pkgs/`, and every `pkgs.<name>`, `services.<name>`, `programs.<name>` and
`virtualisation.<name>` reference in the tree, each with its possessive form.
Every term whose casing is enforced contributes its lowercase form as well, so
a casing mistake is reported once, as casing.

Two allow-lists are maintained by hand, for names that are proper nouns rather
than identifiers:

- `programmer.txt` holds general technical vocabulary.
- `ignore.txt` holds upstream product, service and tool names.

Option names, field names, unit names and other identifiers belong in
backticks in the prose instead. Vale ignores code spans, so an identifier that
is written as code never needs an entry here.

## Host Name And Term Casing

The generated `AU-English/Terms.yml` rule enforces the documentation form of
both host names and the hand-written entries in `ignore.txt`. Nix writes host
names without capitals, so `nix<rest>` becomes `Nix<Rest>`, with `nixio` and
`nixai` as exceptions. A wrongly cased reference is reported as such rather
than as a misspelling:

```
Use 'NixMon' rather than 'nixmon'.
```

Two things stay out of the rule. The lowercased names the scan picks up would
start rejecting their own capitalised forms, and domains, file names and
`mdBook` include directives are not prose, so the config ignores those blocks.

To stop enforcing the casing of a hand-listed name, list its lowercase form as
well: `Homebox` and `homebox` together leave both casings accepted.

## US Spellings Must Keep Failing

Only the Australian spelling of a word is correct here, and the `tech`
dictionary builder is what keeps it that way. Candidates are lowercased, so a
US spelling in one of the source lists would make every casing of that word
acceptable. The builder therefore rewrites what it finds:

- `-ize` and `-yze` become `-ise` and `-yse`, so `anonymize` and `analyze` from
  the source lists are stored as `anonymise` and `analyse`.
- A listed set of US spellings is mapped to its Australian form, such as
  `behavior` to `behaviour` and `color` to `colour`.

Identifiers that end in `size` without being `-ize` verbs, such as `bitsize`,
are listed so the rewrite leaves them alone. Everything else the source lists
offer is kept as it stands, so US vocabulary with no Australian equivalent
turns up in the dictionary too.

To allow a term:

1. Prefer wrapping it in backticks, which excludes it from the check.
1. Add it to `ignore.txt` or `programmer.txt`.
1. Extend the scan in `install-vale-dictionaries.nu` when a whole option
   namespace is missing.
1. Add a list to `vale-tech-dictionary.nu` when a whole category of vocabulary
   is missing, and re-check that no US spelling starts passing.

[cspell]: https://cspell.org
[vale]: https://vale.sh
