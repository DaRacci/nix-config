{ lib }:
let
  inherit (lib) nameValuePair mapAttrs';
  inherit (lib.mine.strings) toSnakeCase;
in
rec {
  # User IDs for Home Assistant user conditions
  ids = {
    james = "3eea636aa3de4c7f9c662ad29c6e92e0";
    savannah = "82def695e9504f63b1eb09150073737d";
  };

  # User display names for UI labels
  users = {
    james = "James";
    savannah = "Savannah";
  };

  # Centralized entity definitions to avoid duplication
  entities = {
    # Sensors
    sensors = {
      uptimekuma = "sensor.uptimekuma_uptime_racci_dev";
      musicRoom = "sensor.music_room";
      musicAssistantPlaying = "sensor.music_assistant_playing_devices";
      timeOfDay = "sensor.time_of_day";
      time = "sensor.time";
      windowOpenCount = "sensor.window_open_count";
      lightsOnCount = "sensor.lights_on_count";
      choresOnCount = "sensor.chores_on_count";
      batteryHealthAttention = "sensor.battery_health_attention";
      batteryLevelAttention = "sensor.battery_level_attention";
      monitoredEntities = "sensor.monitored_entities";
      powerConsumption = "sensor.power_consumption";
      homeAssistantUpdate = "sensor.home_assistant_update";
      # Timers
      kitchenTimer = "sensor.kitchen_timer";
      livingRoomTimer = "sensor.living_room_timer";
      bedroomTimer = "sensor.bed_room_timer";
      bathroomTimer = "sensor.bathroom_timer";
      officeTimer = "sensor.office_timer";
      # 3D Printer
      printerState = "sensor.k1c_276e_current_print_state";
      printerProgress = "sensor.k1c_276e_progress";
      # Gaming
      ps5Activity = "sensor.ps5_343_activity";
      steamActivity = "sensor.steam_76561197981585794";
      # Alarm
      wakeTime = "sensor.wake_time_1";
      isAlarmOn = "sensor.is_alarm_on";
    };

    # Binary sensors
    binarySensors = {
      alexaTimerActive = "binary_sensor.alexa_timer_active";
      batteryHealthAttention = "binary_sensor.battery_health_attention";
      monitoredEntities = "binary_sensor.monitored_entities";
      isAlarmOn = "binary_sensor.is_alarm_on";
      homeAssistantUpdate = "binary_sensor.home_assistant_update";
    };

    # Input booleans
    inputBooleans = {
      debugRounded = "input_boolean.debug_rounded";
      vacationMode = "input_boolean.vacation_mode";
      soundAlarmRunning = "input_boolean.sound_alarm_is_running";
      alarmSnoozed = "input_boolean.alarm_snoozed";
      notificationsJames = "input_boolean.notifications_james_phone";
      notificationsSavannah = "input_boolean.notifications_savannah_phone";
      musicPlayerIdleHelper = "input_boolean.music_player_idle_helper";
    };

    # Persons
    persons = {
      james = "person.james";
      savannah = "person.savannah";
    };

    # Other
    alarm = "alarm_control_panel.security_system";
    adguardProtection = "switch.adguard_home_protection";
    adguardSpeed = "sensor.adguard_home_average_processing_speed";
  };

  # Centralized media player entity definitions
  mediaPlayers = {
    # Room-based speakers
    rooms = {
      living_room = "media_player.living_room";
      kitchen = "media_player.kitchen";
      bed_room = "media_player.bed_room";
      bedroom_speakers = "media_player.bedroom_speakers";
      bedroom_nest = "media_player.bedroom_nest_music_assistant";
      bathroom = "media_player.bathroom";
      everywhere = "media_player.everywhere";
      spare_room = "media_player.spare_room";
    };

    # Devices that also act as media players
    special = {
      apple_tv = "media_player.apple_tv";
      music = "media_player.music";
      music_and_tv = "media_player.music_and_tv";
      steam = "media_player.steam_jlnbln";
    };
  };

  jsColours = {
    yellow = "var(--yellow)";
    orange = "var(--orange)";
    black = "var(--black)";
    blue = "var(--blue)";
    contrast2 = "var(--contrast2)";
    contrast20 = "var(--contrast20)";
  };

  # Helper to create a music room button card for the desktop view
  mkMusicRoomButton =
    {
      room, # entity suffix (e.g., "bed_room")
      icon,
      script, # script to call on double tap
    }:
    {
      type = "custom:button-card";
      entity = "media_player.${room}";
      inherit icon;
      show_label = false;
      show_state = true;
      show_entity_picture = true;
      styles = {
        card = [
          { border-radius = "0px"; }
          { box-shadow = "none"; }
          { padding-right = "5px"; }
          { background = "none"; }
        ];
        grid = [
          { grid-template-areas = ''" 'i n' 'i s' "''; }
          { grid-template-columns = "min-content"; }
          { column-gap = "10px"; }
        ];
        entity_picture = [ { border-radius = "100%"; } ];
        icon = [ { width = 20; } ];
        img_cell = [ { width = 20; } ];
        name = [
          { justify-self = "start"; }
          { font-size = 10; }
          { font-weight = 500; }
          { color = "var(--contrast14)"; }
        ];
        state = [
          { justify-self = "start"; }
          { font-size = 15; }
          { font-weight = 700; }
        ];
      };
      tap_action.action = "more-info";
      double_tap_action = {
        action = "perform-action";
        perform_action = script;
      };
    };

  # Helper to create a mobile music room transfer button
  mkMusicRoomTransferButton =
    {
      room, # entity suffix
      icon,
      color,
      targetEntity, # entity to transfer to
      script, # script for double tap
    }:
    {
      type = "custom:button-card";
      entity = "media_player.${room}";
      inherit icon;
      show_name = false;
      aspect_ratio = "1/1";
      state = [
        {
          value = "playing";
          icon = "mdi:play-circle-outline";
        }
        {
          value = "paused";
          icon = "mdi:pause-circle-outline";
        }
      ];
      tap_action = {
        action = "call-service";
        service = "music_assistant.transfer_queue";
        data.source_player = jsMatch {
          value = "states['sensor.music_room'].state";
          cases = [
            {
              match = "Living Room";
              ret = "'${mediaPlayers.rooms.living_room}'";
            }
            {
              match = "Kitchen";
              ret = "'${mediaPlayers.rooms.kitchen}'";
            }
            {
              match = "Bathroom";
              ret = "'${mediaPlayers.rooms.bathroom}'";
            }
            {
              match = "Bedroom";
              ret = "'${mediaPlayers.rooms.bedroom_speakers}'";
            }
            {
              match = "Spare Room";
              ret = "'${mediaPlayers.rooms.spare_room}'";
            }
            {
              match = "Everywhere";
              ret = "'${mediaPlayers.rooms.everywhere}'";
            }
          ];
          default = "''";
        };
        target.entity_id = targetEntity;
        haptic = "success";
      };
      double_tap_action = {
        action = "call-service";
        service = script;
        haptic = "success";
      };
      styles.card = [
        { border-radius = "12px"; }
        { background-color = "var(--${color})"; }
      ];
      styles.icon = [ { color = "var(--black)"; } ];
    };

  # Helper to create a conditional swipe card for a music room
  mkMusicSwipeCard =
    {
      room, # display name (e.g., "Living Room")
      entity, # full entity id
      conditionEntity ? entity, # entity to check for playing/paused state
    }:
    {
      type = "conditional";
      conditions = [
        {
          condition = "numeric_state";
          entity = "sensor.music_assistant_playing_devices";
          above = 1;
        }
        {
          condition = "state";
          entity = mediaPlayers.rooms.everywhere;
          state_not = "playing";
        }
        {
          condition = "state";
          entity = entities.sensors.musicRoom;
          state_not = room;
        }
        {
          condition = "or";
          conditions = [
            {
              condition = "state";
              entity = conditionEntity;
              state = "paused";
            }
            {
              condition = "state";
              entity = conditionEntity;
              state = "playing";
            }
          ];
        }
      ];
      card = {
        type = "custom:button-card";
        inherit entity;
        template = "media_player";
        variables.room = room;
        variables.icon_1 = ''<ha-icon icon="mdi:arrow-down"></ha-icon>'';
      };
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
      entity = entities.binarySensors.alexaTimerActive;
      state = "on";
    };
    alarmActive = condState {
      entity = entities.inputBooleans.soundAlarmRunning;
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

    getState = entity: ''
      [[[
        return states[ "${entity}" ].state;
      ]]]
    '';

    returnIcon = icon: ''
      [[[
        return '<ha-icon icon="${icon}"></ha-icon>';
      ]]]
    '';

    stateOnIfElse =
      {
        entity ? "entity.state",
        valueOn ? true,
        valueOff ? false,
      }:
      template.stateIfElse {
        inherit entity;
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
        card = [ { background-color = "[[[ return variables.background_color_${state} ]]]"; } ];
        name = [ { color = "[[[ return variables.color_${state} ]]]"; } ];
        label = [ { color = "[[[ return variables.color_${state} ]]]"; } ];
        icon = [ { color = "[[[ return variables.color_${state} ]]]"; } ];
      };
    };
  };

  compact = attrs: lib.filterAttrs (_: v: v != null) attrs;

  parseConvertCompact =
    attrs: attrs |> compact |> mapAttrs' (name: value: nameValuePair (toSnakeCase name) value);

  # Convert a style attrset to an array of single-key objects for button-card
  # { a = 1; b = 2; } -> [ { a = 1; } { b = 2; } ]
  styleArray = attrs: lib.mapAttrsToList (n: v: { ${n} = v; }) attrs;

  # Convert a full styles block where each key (card, icon, etc.) needs to be an array
  # Recursively handles nested custom_fields
  mkStyles =
    styles:
    lib.mapAttrs (
      name: value:
      if name == "custom_fields" then
        # custom_fields is nested - each field's styles should also be arrays
        lib.mapAttrs (_: styleArray) value
      else if !lib.isAttrs value then
        # Not an attrset, leave as-is
        value
      else
        styleArray value
    ) styles;

  colourOnOff = on: off: ''
    [[[
      if (entity && entity.state == "on") return "var(--${on})";
      else return "var(--${off})";
    ]]]
  '';

  # Generate a JavaScript template with match/switch-like semantics
  # Usage:
  #   jsMatch {
  #     value = "entity.state";  # or "states['sensor.foo'].state"
  #     cases = [
  #       { match = "on"; ret = "'green'"; }
  #       { match = "off"; ret = "'red'"; }
  #       { match = [ "unavailable" "unknown" ]; ret = "'gray'"; }  # multiple values
  #     ];
  #     default = "'black'";  # optional, defaults to "null"
  #   }
  # Produces:
  #   [[[
  #     const v = entity.state;
  #     if (v === "on") return 'green';
  #     if (v === "off") return 'red';
  #     if (v === "unavailable" || v === "unknown") return 'gray';
  #     return 'black';
  #   ]]]
  jsMatch =
    {
      value,
      cases,
      default ? "null",
    }:
    let
      mkCondition =
        m:
        if builtins.isList m then
          builtins.concatStringsSep " || " (map (w: ''v === "${w}"'') m)
        else
          ''v === "${m}"'';

      mkCase = { match, ret, ... }: "if (${mkCondition match}) return ${ret};";

      caseLines = map mkCase cases;
    in
    ''
      [[[
        const v = ${value};
        ${builtins.concatStringsSep "\n    " caseLines}
        return ${default};
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
    parseConvertCompact {
      condition = "state";
      inherit entity state state_not;
    };

  condNumericState =
    {
      entity,
      above ? null,
      below ? null,
    }:
    parseConvertCompact {
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
      card = {
        type = "markdown";
        inherit text_only content;
        visibility = [
          {
            condition = "screen";
            inherit media_query;
          }
        ];
      }
      // cardOverrides;
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
    parseConvertCompact {
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
    lib.warn "Convert to mkEntity, shit stain" (parseConvertCompact {
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
    });

  mkEntity =
    {
      entity,
      name ? null,
      icon ? null,
      color ? null,
      iconColor ? null,
      visibility ? null,
      contentInfo ? null,
      stateContent ? null,
      showName ? null,
      showState ? null,
      showIcon ? null,
      showEntityPicture ? null,
      tapAction ? null,
    }:
    parseConvertCompact {
      type = "entity";
      inherit
        entity
        name
        icon
        color
        iconColor
        visibility
        contentInfo
        stateContent
        showName
        showState
        showIcon
        showEntityPicture
        tapAction
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
    parseConvertCompact {
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

  mkMushroomChipsCard =
    {
      chips,
      alignment ? "center",
    }:
    parseConvertCompact {
      type = "custom:mushroom-chips-card";
      inherit chips alignment;
    };

  mkAction =
    {
      action,
      haptic ? null,
    }:
    parseConvertCompact {
      inherit action haptic;
    };

  mkGridSection =
    {
      cards,
      columns ? null,
      grid_options ? null,
      visibility ? null,
      column_span ? null,
    }:
    parseConvertCompact {
      type = "grid";
      inherit
        cards
        columns
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

  # Convert attribute names from camelCase to snake_case for card definitions
  # Does not recurse into nested attrsets
  convertNames =
    attrsList:
    attrsList |> map (_attrs: mapAttrs' (name: value: nameValuePair (toSnakeCase name) value));

  mkBubbleCard =
    {
      name ? null,
      entity ? null,
      icon ? null,
      hash ? null,

      cardType,
      subButton ? [ ],
      showState ? null,
      showName ? null,
      showIcon ? null,
      scrollingEffect ? null,

      tapAction ? null,
      doubleTapAction ? null,
      holdAction ? null,
      buttonAction ? null,

      openAction ? null,
      closeAction ? null,

      buttonType ? "name",
      cardLayout ? "large",
      hideBackdrop ? null,
      styles ? null,
    }:
    parseConvertCompact {
      type = "custom:bubble-card";
      inherit
        name
        entity
        icon
        hash
        cardType
        subButton
        showState
        showName
        showIcon
        scrollingEffect
        tapAction
        doubleTapAction
        holdAction
        buttonAction
        openAction
        closeAction
        buttonType
        cardLayout
        hideBackdrop
        styles
        ;
    };

  mkButtonCard =
    {
      entity ? null,
      name ? null,
      label ? null,
      icon ? null,
      template ? null,

      showName ? null,
      showIcon ? null,
      showLabel ? null,
      showState ? null,

      tapAction ? null,
      holdAction ? null,

      variables ? { },
      styles ? { },
      customFields ? { },
    }:
    parseConvertCompact {
      type = "custom:button-card";
      inherit
        entity
        name
        label
        icon
        template
        showName
        showIcon
        showLabel
        showState
        tapAction
        holdAction
        styles
        customFields
        ;
      variables = parseConvertCompact variables;
    };

  mkSwipeCard =
    {
      cardWidth ? null,
      parameters ? null,
      cards ? [ ],
    }:
    parseConvertCompact {
      type = "custom:swipe-card";
      inherit cardWidth parameters cards;
    };

  mkDeclutteringCard =
    {
      template,
      variables ? null,
    }:
    parseConvertCompact {
      type = "custom:decluttering-card";
      inherit template variables;
    };

  standardBadges = [
    (mkEntity {
      entity = "input_boolean.vacation_mode";
      color = "orange";
      tapAction.action = "toggle";
      visibility = [
        (condState {
          entity = "input_boolean.vacation_mode";
          state = "on";
        })
      ];
    })

    (mkEntity {
      entity = "input_boolean.notifications_james_phone";
      color = "primary";
      tapAction.action = "toggle";
      visibility = [
        (condState {
          entity = "input_boolean.notifications_james_phone";
          state = "off";
        })
        (condUser [ ids.james ])
      ];
    })

    (mkEntity {
      entity = "input_boolean.notifications_savannah_phone";
      color = "primary";
      icon = "mdi:cellphone-message-off";
      showEntityPicture = false;
      tapAction.action = "toggle";
      visibility = [
        (condState {
          entity = "input_boolean.notifications_savannah_phone";
          state = "off";
        })
        (condUser [ ids.savannah ])
      ];
    })

    (mkEntity {
      entity = "sensor.chores_on_count";
      color = "yellow";
      showState = true;
      tapAction = {
        action = "navigate";
        navigationPath = "home#chores";
      };
      visibility = [
        (condNumericState {
          entity = "sensor.chores_on_count";
          above = 0;
        })
      ];
    })

    (mkEntity {
      entity = "sensor.k1c_276e_progress";
      showState = true;
      icon = "mdi:printer-3d";
      color = "orange";
      visibility = [
        (condState {
          entity = "sensor.k1c_276e_current_print_state";
          state = "printing";
        })
        (condUser [ "3eea636aa3de4c7f9c662ad29c6e92e0" ])
      ];
      tapAction = {
        action = "navigate";
        navigationPath = "server#3d-printer";
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
