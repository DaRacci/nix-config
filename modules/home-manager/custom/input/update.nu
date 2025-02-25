#!/usr/bin/env nix-shell
#! nix-shell -i nu -p gojq curl

# Zed-Editor Keymap https://github.com/zed-industries/zed/blob/main/assets/keymaps/default-linux.json
# Micro Keymap https://github.com/zyedidia/micro/blob/master/runtime/help/keybindings.md
# VSCode Keymap https://code.visualstudio.com/docs/getstarted/keybindings
# Helix Keymap https://docs.helix-editor.com/keymap.html

def parse_zed-editor [] {
  const URL = "https://raw.githubusercontent.com/zed-industries/zed/main/assets/keymaps/default-linux.json"
  let json = http get $URL
  let contexts = $json | get -i context | filter {|c| $c != null}
  let actions = $json | get bindings | each {|b| $b | values } | flatten

  return {
    contexts: ($contexts | uniq | sort ),
    actionsNoArgs: ($actions | filter {|a| ($a| describe ) == 'string' }| uniq | sort ),
    # TODO - Add specific arg types and properties to the actions instead of just an array
    actionsWithArgs: ($actions | filter {|a| ($a| describe ) != 'string' }| each {|a| $a | get 0 } | uniq | sort )
  }
}

def parse_micro [] {
  const URL = "https://raw.githubusercontent.com/zyedidia/micro/refs/heads/master/runtime/help/keybindings.md";
  let raw_text = http get $URL
  let actions = $raw_text | lines
    | skip until {|line| $line == "Full list of possible actions:" }
    | skip 1
    | skip until {|line| $line == "```" }
    | skip 1
    | take until {|line| $line == "```" }
    | each {|line|
      let captures = $line | parse --regex '(\w+)'
      if ($captures | is-not-empty) {
        $captures.capture0.0
      }
    }

  return {
    keybinds: ($actions | uniq | sort )
  }
}

def update_schema [] {
  let directory = $env.FILE_PWD
  let schema_file = $"($directory )/bindings.schema.json"
  let schema = open $schema_file

  let zed_editor = parse_zed-editor
  let updated_schema = $schema
    | update definitions.zed-editor-action.oneOf.0.enum $zed_editor.actionsNoArgs
    | update definitions.zed-editor-action.oneOf.1.properties.action.enum $zed_editor.actionsWithArgs
    | update definitions.zed-editor-context.enum $zed_editor.contexts

  let micro = parse_micro
  let updated_schema = $updated_schema
    | update definitions.micro-action.enum $micro.keybinds

  $updated_schema | save $schema_file -f;
}

update_schema
