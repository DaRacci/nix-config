#!/usr/bin/env nu

# Build the `tech` hunspell dictionary from a fixed subset of the cspell
# wordlists, so ordinary programming vocabulary stops being flagged while US
# spellings keep failing. The wordlists come from the `cspell` package rather
# than being vendored.
#
# Reads $CSPELL, writes $out/tech.dic and $out/tech.aff.

# cspell ships one wordlist per language and toolchain. Only the general
# software and tooling lists are used: the per-language lists are mostly
# language keywords and US-spelled identifiers, and the brand, coin, font and
# game lists are noise for prose.
const WORDLISTS = [
  { package: "@cspell/dict-software-terms", path: "dict/*.txt" }
  { package: "@cspell/dict-shell", path: "dict/*.txt" }
  { package: "@cspell/dict-git", path: "dict/git-terms.txt" }
  { package: "@cspell/dict-docker", path: "dict/docker-words.txt.gz" }
  { package: "@cspell/dict-terraform", path: "dict/terraform.txt" }
]

# A cspell update that moves these files should fail loudly rather than
# silently produce a smaller dictionary.
const EXPECTED_WORDLISTS = 11

# US spellings that must keep failing, paired with their Australian forms. The
# base dictionary rejects the left-hand side, so only the right-hand side is
# kept and the US spelling stays an error.
const US_SPELLINGS = {
  aluminum: aluminium
  behavior: behaviour
  canceled: cancelled
  catalog: catalogue
  center: centre
  color: colour
  defense: defence
  enroll: enrol
  mom: mum
  skeptical: sceptical
  specialty: speciality
}

# Identifiers ending in `size`, which are not `-ize` verbs and so must not be
# rewritten to `-ise`.
const SIZE_IDENTIFIERS = [
  bitsize
  bsize
  bufsize
  dsize
  fixedsize
  histfilesize
  histsize
  imagesize
  lsize
  rsize
  tsize
]

# `-ize` and `-yze` are the US forms; the base dictionary accepts only `-ise`
# and `-yse`, so the rewrite is what keeps the US spelling failing. Longest
# suffix first, since the first match wins.
const SUFFIX_RULES = [
  { us: "izations", au: "isations" }
  { us: "ization", au: "isation" }
  { us: "izers", au: "isers" }
  { us: "izer", au: "iser" }
  { us: "izes", au: "ises" }
  { us: "ized", au: "ised" }
  { us: "izing", au: "ising" }
  { us: "ize", au: "ise" }
  { us: "yzes", au: "yses" }
  { us: "yzed", au: "ysed" }
  { us: "yzing", au: "ysing" }
  { us: "yze", au: "yse" }
]

# cspell keeps each wordlist under a pnpm directory named after the package and
# its version, so the path is assembled rather than written out.
def wordlist_files [cspell: string, wordlist: record] {
  let pnpm_dir = ($wordlist.package | str replace "@cspell/" "@cspell+")
  glob $"($cspell)/lib/node_modules/cspell/node_modules/.pnpm/($pnpm_dir)@*/node_modules/($wordlist.package)/($wordlist.path)"
}

def wordlist_lines [file: string] {
  if ($file | str ends-with ".gz") {
    (^gzip -dc $file | complete).stdout | lines
  } else {
    open --raw $file | lines
  }
}

# Only the `-or` stems that appear with an `-ize` suffix need repairing here.
def australian_stem [word: string] {
  if ($word | str starts-with "coloriz") {
    $"colour($word | str substring 5..)"
  } else {
    $word
  }
}

def australian_spelling [word: string] {
  for rule in $SUFFIX_RULES {
    if ($word | str ends-with $rule.us) {
      let keep = (($word | str length) - ($rule.us | str length))
      return $"($word | str substring 0..<($keep))($rule.au)"
    }
  }
  $word
}

def main [] {
  let cspell = ($env.CSPELL? | default "")
  if $cspell == "" {
    error make { msg: "$CSPELL is not set" }
  }

  let wordlists = (
    $WORDLISTS
    | each { |wordlist| wordlist_files $cspell $wordlist }
    | flatten
  )
  if ($wordlists | length) != $EXPECTED_WORDLISTS {
    error make { msg: $"expected ($EXPECTED_WORDLISTS) cspell wordlists, found ($wordlists | length)" }
  }

  let words = (
    $wordlists
    | each { |file| wordlist_lines $file }
    | flatten
    | where { |line| not ($line | str starts-with "#") }
    | where { |line| ($line | str trim) != "" }
    | where { |line| not ($line | str starts-with "~") and not ($line | str starts-with "*") }
    | where { |line| not ($line =~ '\s') }
    | where { |line| not ($line | str contains "/") }
    | where { |line| ($line | str length) >= 2 }
    | each { str lowercase }
    # Drop CLI flags, hex constants and cspell prefix/suffix markers, while
    # keeping possessives and the digits in terms like base64.
    | where { |word|
        let check = ($word | str replace --all "'" "")
        if not ($check =~ '^[a-z][a-z0-9._-]*$') {
          false
        } else {
          not (($check =~ '^[a-f0-9]{4,}$') and ($check =~ '[0-9]'))
        }
      }
    | each { |word|
        let check = ($word | str replace --all "'" "")
        if ($check in $US_SPELLINGS) {
          $US_SPELLINGS | get $check
        } else if ($check in $SIZE_IDENTIFIERS) {
          $check
        } else {
          # Rewrite the word itself rather than the sanitised copy, so
          # possessives keep their apostrophe.
          australian_spelling (australian_stem $word)
        }
      }
    | sort
    | uniq
  )

  mkdir ($env.out)
  let dictionary = ([($words | length | into string)] | append $words | str join "\n")
  $"($dictionary)\n" | save --force $"($env.out)/tech.dic"
  "SET UTF-8\n" | save --force $"($env.out)/tech.aff"
}
