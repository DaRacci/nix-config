{ lib }:
rec {
  ids = {
    james = "3eea636aa3de4c7f9c662ad29c6e92e0";
    savannah = "82def695e9504f63b1eb09150073737d";
  };

  entity = {
    id = "[[[ return entity.entity_id ]]]";
    icon = "[[[ return entity.attributes.icon ]]]";
    name = "[[[ return entity.attributes.friendly_name ]]]";
    state = "[[[ return entity.state ]]]";
    attribute = attr: "[[[ return entity.attributes[\"${attr}\"] ]]]";
  };

  card = {
    timer = {
      type = "custom:button-card";
      template = "custom_card_timer_bottom";
    };

    alarm = {
      type = "custom:button-card";
      template = "custom_card_alarm_bottom";
    };

    mediaPlayer = entity: {
      type = "custom:button-card";
      template = "custom_card_mediaplayer_bottom";
      entity = "media_player.${entity}";
    };
  };

  condition = {
    mobileOnly = condScreen "(min-width: 0px) and (max-width: 767px)";
    desktopOnly = condScreen "(min-width: 768px)";

    tvActive = condOr [
      (condState {
        entity = "media_player.apple_tv";
        state = "playing";
      })
      (condState {
        entity = "media_player.apple_tv";
        state = "paused";
      })
    ];

    musicPlaying = condOr [
      (condState {
        entity = "media_player.spotify";
        state = "playing";
      })
      (condState {
        entity = "media_player.spotify";
        state = "paused";
      })
      (condState {
        entity = "media_player.music";
        state = "playing";
      })
      (condState {
        entity = "media_player.music";
        state = "paused";
      })
    ];

    timerActive = condState {
      entity = "binary_sensor.alexa_timer_active";
      state = "on";
    };
    alarmActive = condState {
      entity = "input_boolean.sound_alarm_is_running";
      state = "on";
    };
  };

  template = {
    remainingTime = ''
      [[[
        var remainingTime = states[ entity.entity_id ].attributes.remaining;
        return `''${remainingTime}`;
      ]]]
    '';

    stateOnIfElse =
      {
        entity ? "entity.state",
        valueOn ? true,
        valueOff ? false,
      }:
      template.stateIfElse {
        entity = entity;
        states = [ "on" ];
        ifTrue = valueOn;
        ifFalse = valueOff;
      };

    stateIfElse =
      {
        entity ? "entity.entity_id",
        states,
        ifTrue ? true,
        ifFalse ? false,
      }:
      let
        state = if (entity |> lib.hasSuffix "state") then entity else "states[\"" + entity + "\"].state";

        compareTo =
          if (builtins.isList states) then
            "in [ [[${builtins.concatStringsSep "," states}]] ]"
          else
            "== '${states}'";
      in
      ''
        [[[
          if (${state} ${compareTo}) {
            return ${ifTrue};
          } else {
            return ${ifFalse};
          }
        ]]]
      '';
  };

  style = {
    iconState = state: {
      value = "[[[ return variables.state_${state} ]]]";
      icon = "[[[ return variables.icon_${state} ]]]";
      styles = {
        card.background-color = "[[[ return variables.background_color_${state} ]]]";
        name.color = "[[[ return variables.color_${state} ]]]";
        label.color = "[[[ return variables.color_${state} ]]]";
        icon.color = "[[[ return variables.color_${state} ]]]";
      };
    };
  };

  compact = attrs: lib.filterAttrs (_: v: v != null) attrs;

  colourOnOff = on: off: ''
    [[[
      if (entity.state == "on") return "var(--${on})";
      else return "var(--${off})";
    ]]]
  '';

  condScreen = media_query: {
    condition = "screen";
    inherit media_query;
  };

  condState =
    {
      entity,
      state ? null,
      state_not ? null,
    }:
    compact {
      condition = "state";
      inherit entity state state_not;
    };

  condNumericState =
    {
      entity,
      above ? null,
      below ? null,
    }:
    compact {
      condition = "numeric_state";
      inherit entity above below;
    };

  condUser = users: {
    condition = "user";
    inherit users;
  };

  condAnd = conditions: {
    condition = "and";
    inherit conditions;
  };

  condOr = conditions: {
    condition = "or";
    inherit conditions;
  };

  mkHeader =
    {
      content,
      text_only ? true,
      media_query ? "(min-width: 768px)",
      layout ? "responsive",
      badges_position ? "top",
      badges_wrap ? "scroll",
      cardOverrides ? { },
    }:
    {
      card = (
        {
          type = "markdown";
          inherit text_only content;
          visibility = [
            {
              condition = "screen";
              media_query = media_query;
            }
          ];
        }
        // cardOverrides
      );
      inherit layout badges_position badges_wrap;
    };

  mkView =
    {
      title,
      header,
      badges ? [ ],
      sections ? [ ],
      theme ? "Rounded-Bubble",
      dense_section_placement ? false,
      path ? null,
      icon ? null,
      type ? "sections",
      max_columns ? null,
    }:
    compact {
      inherit
        title
        header
        badges
        sections
        theme
        dense_section_placement
        path
        icon
        type
        max_columns
        ;
    };

  mkBadgeEntity =
    {
      entity,
      show_name ? false,
      show_state ? false,
      show_icon ? true,
      color ? null,
      tap_action ? null,
      visibility ? null,
      icon ? null,
      show_entity_picture ? null,
      name ? null,
    }:
    compact {
      type = "entity";
      inherit
        entity
        show_name
        show_state
        show_icon
        color
        tap_action
        visibility
        icon
        show_entity_picture
        name
        ;
    };

  mkMushroomTemplateBadge =
    {
      content,
      icon,
      color,
      picture ? null,
      entity ? null,
      label ? null,
      double_tap_action ? null,
      tap_action ? null,
      visibility ? null,
    }:
    compact {
      type = "custom:mushroom-template-badge";
      inherit
        content
        icon
        color
        picture
        entity
        label
        double_tap_action
        tap_action
        visibility
        ;
    };

  mkGridSection =
    {
      cards,
      grid_options ? null,
      visibility ? null,
      column_span ? null,
    }:
    compact {
      type = "grid";
      inherit
        cards
        grid_options
        visibility
        column_span
        ;
    };

  mkVerticalStack =
    {
      cards,
      visibility ? null,
    }:
    compact {
      type = "vertical-stack";
      inherit cards visibility;
    };

  mkConditional =
    {
      conditions,
      card,
    }:
    {
      type = "conditional";
      inherit conditions card;
    };

  mkHeading =
    {
      heading,
      icon ? null,
      heading_style ? "title",
      badges ? null,
      tap_action ? null,
      visibility ? null,
      grid_options ? null,
    }:
    compact {
      type = "heading";
      inherit
        heading
        icon
        heading_style
        badges
        tap_action
        visibility
        grid_options
        ;
    };

  mkDeclutteringCard =
    {
      template,
      variables ? null,
    }:
    compact {
      type = "custom:decluttering-card";
      inherit template variables;
    };

  standardBadges = [
    (mkBadgeEntity {
      entity = "input_boolean.vacation_mode";
      color = "orange";
      tap_action.action = "toggle";
      visibility = [
        (condState {
          entity = "input_boolean.vacation_mode";
          state = "on";
        })
      ];
    })

    (mkBadgeEntity {
      entity = "input_boolean.notifications_james_phone";
      color = "primary";
      tap_action.action = "toggle";
      visibility = [
        (condState {
          entity = "input_boolean.notifications_james_phone";
          state = "off";
        })
        (condUser [ ids.james ])
      ];
    })

    (mkBadgeEntity {
      entity = "input_boolean.notifications_savannah_phone";
      color = "primary";
      icon = "mdi:cellphone-message-off";
      show_entity_picture = false;
      tap_action.action = "toggle";
      visibility = [
        (condState {
          entity = "input_boolean.notifications_savannah_phone";
          state = "off";
        })
        (condUser [ ids.savannah ])
      ];
    })

    (mkBadgeEntity {
      entity = "sensor.chores_on_count";
      color = "yellow";
      show_state = true;
      tap_action = {
        action = "navigate";
        navigation_path = "home#chores";
      };
      visibility = [
        (condNumericState {
          entity = "sensor.chores_on_count";
          above = 0;
        })
      ];
    })

    (mkBadgeEntity {
      entity = "sensor.k1c_276e_progress";
      show_state = true;
      icon = "mdi:printer-3d";
      color = "orange";
      visibility = [
        (condState {
          entity = "sensor.k1c_276e_current_print_state";
          state = "printing";
        })
        (condUser [ "3eea636aa3de4c7f9c662ad29c6e92e0" ])
      ];
      tap_action = {
        action = "navigate";
        navigation_path = "server#3d-printer";
      };
    })

    (mkMushroomTemplateBadge {
      icon = "mdi:account-tie-voice";
      color = "white";
      content = "";
      tap_action.action = "assist";
      visibility = [ (condScreen "(min-width: 768px)") ];
    })

    (mkMushroomTemplateBadge {
      entity = "person.james";
      picture = ''{{ state_attr("person.james","entity_picture") }}'';
      content = ''{{ states("person.james") }}'';
      label = "James";
      icon = "";
      color = "";
      tap_action = {
        action = "navigate";
        navigation_path = "home#james";
      };
      visibility = [
        (condScreen "(min-width: 768px)")
        (condUser [ ids.james ])
      ];
    })
  ];
}
