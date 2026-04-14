#!/usr/bin/env nu

use std/log

const TYPES = ["A", "M", "D"]

def getFiles [dir: path] {
  let expanded = ($dir | path expand)
  ^find $expanded -type f -not -path $"($expanded)/.git/*" -print
    | lines
    | where { |f| $f != "" }
    | each { |f| $f | str replace $"($expanded)/" "" }
    | sort
}

def setupGit [tmp: path] {
  cd $tmp
  try {
    git init -q
    git config user.name temp
    git config user.email temp@temp.com
    git config set advice.addIgnoredFile false
    git add -A
    git commit -q -m "left"
  } catch { |_e|
    log critical "Failed to set up git repository in temp directory."
    rm -rf $tmp
    exit 1
  }
}

def trackModified [right: path, left_files: list<string>, right_files: list<string>, tmp: path] {
  let common = ($left_files | where { |f| $f in $right_files })

  cd $tmp

  mut modified_count = 0
  for $rel in $common {
    let parent = ($rel | path dirname)
    if $parent != "" and $parent != "." { mkdir $parent }
    cp $"($right)/($rel)" $rel
    $modified_count += 1
    git add -- $rel
  }

  return $modified_count
}

def trackAdded [right: path, left_files: list<string>, right_files: list<string>, tmp: path] {
  let added = ($right_files | where { |f| $f not-in $left_files })

  cd $tmp

  mut added_count = 0
  for $rel in $added {
    let parent = ($rel | path dirname)
    if $parent != "" and $parent != "." { mkdir $parent }
    cp $"($right)/($rel)" $rel
    $added_count += 1
    git add --force -- $rel
  }

  return $added_count
}

def trackRemoved [left_files: list<string>, right_files: list<string>, tmp: path] {
  let deleted = ($left_files | where { |f| $f not-in $right_files })

  cd $tmp

  mut deleted_count = 0
  for $rel in $deleted {
    if ($rel | path exists) {
      $deleted_count += 1
      git rm -q -- $rel
    }
  }

  return $deleted_count
}

def commitChanges [tmp: path] {
  cd $tmp

  let status = (git status --porcelain | str trim)
  if $status == "" { return false }

  git commit -q -m "right"
  return true
}

def validatePaths [left: path, right: path] {
  if not ($left | path exists) { log critical $"Left not found: ($left)"; exit 1 }
  if not ($right | path exists) { log critical $"Right not found: ($right)"; exit 1 }
  { left: ($left | path expand), right: ($right | path expand) }
}

def outputChanges [tmp: path] {
  cd $tmp

  git --no-pager diff --binary --full-index HEAD~1 HEAD

  let diff_lines = (^git --no-pager diff --name-status HEAD~1 HEAD | lines)
  mut changes = { }

  for $line in $diff_lines {
    let row_elements = $line | str trim | split row "\t"
    let status = ($row_elements | get 0)
    let file = ($row_elements | get 1)
    log debug $"Processing diff line: ($line) - status: ($status), file: ($file)"

    if $status == "A" {
      $changes = $changes | upsert added ($changes | get added -o | default [] | append $file)
    } else if $status == "D" {
      $changes = $changes | upsert deleted ($changes | get deleted -o | default [] | append $file)
    } else if $status == "M" {
      $changes = $changes | upsert modified ($changes | get modified -o | default [] | append $file)
    }
  }

  $changes | items {|key, value|
    log debug $"Change type: ($key), files: ($value)"

    if ($value | length) > 0 {
      print --stderr $"($key | str upcase) files:"
      for $f in $value { print --stderr $"\t($f)" }
    }
  }

  return
}

def main [
  trackTypes: string, # comma-separated list of diff types: R(enamed), A(dded), M(odified), D(eleted), e.g. "A,M"
  left: path,
  right: path,
  --verbose
] {
  if $verbose { log set-level 10 }

  mut diff_types = ($trackTypes | split row ",")
  $diff_types | each {
    if ($in not-in $TYPES) { log critical $"Invalid diff type: ($in). Valid types are: ($TYPES)."; exit 1 }
  }

  let paths = validatePaths $left $right
  let left = $paths.left
  let right = $paths.right
  log debug $"Validated paths - Left: ($left), Right: ($right)"

  let tmp = (mktemp -d)
  log debug $"Copying left directory to temp location: ($tmp)"
  rsync -a --exclude=".git" $"($left)/" $"($tmp)/"
  setupGit $tmp
  log debug "Git repository initialized in temp directory."

  let left_files = (getFiles $left)
  let right_files = (getFiles $right)
  log debug $"Collected files - Left: ($left_files | length) files, Right: ($right_files | length) files"

  while ($diff_types | length) > 0 {
    let t = $diff_types | get 0
    log debug $"Processing diff type: ($t)"
    if $t == "M" {
      let file_count = trackModified $right $left_files $right_files $tmp
      log debug $"Tracked modified ($file_count) files."
    } else if $t == "A" {
      let file_count = trackAdded $right $left_files $right_files $tmp
      log debug $"Tracked added ($file_count) files."
    } else if $t == "D" {
      let file_count = trackRemoved $left_files $right_files $tmp
      log debug $"Tracked removed ($file_count) files."
    }

    $diff_types = $diff_types | where { |d| $d != $t }
  }

  let hadChanges = commitChanges $tmp
  if $hadChanges {
    outputChanges $tmp
  } else {
    log info "No changes detected."
  }
}
