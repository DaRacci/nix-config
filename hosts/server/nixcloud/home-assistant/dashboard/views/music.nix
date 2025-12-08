{ lib, ... }:
let
  viewHeader = import ../components/view-header.nix { };
  navbar = import ../components/navbar.nix { };
in
with (import ../lib.nix { inherit lib; });
mkView {
  title = "Music";
  header = viewHeader;
  path = "music";
  icon = "mdi:music";

  badges = standardBadges;

  sections = [
    (mkGridSection {
      cards = [ navbar ];
    })

    # Desktop section: media quick controls (rooms row) + music iframe
    (mkGridSection {
      cards = [
        # Left column: stack of media chips row
        (mkVerticalStack {
          cards = [
            (mkVerticalStack {
              cards = [
                {
                  type = "custom:button-card";
                  styles = {
                    grid = [
                      { grid-template-areas = ''" 'item6 item7 item1 item2 item3 item4 item5' "''; }
                      { grid-template-columns = "1fr 1fr 1fr 1fr 1fr 1fr 1fr"; }
                    ];
                    card = {
                      padding = "5px 0px";
                      background = "none";
                    };
                    custom_fields = {
                      item1.justify-self = "center";
                      item2.justify-self = "center";
                      item3.justify-self = "center";
                      item4.justify-self = "center";
                      item5.justify-self = "center";
                      item6.justify-self = "center";
                      item7.justify-self = "center";
                    };
                  };
                  custom_fields = {
                    item1.card = {
                      type = "custom:button-card";
                      entity = "media_player.bed_room";
                      icon = "mdi:bed-king-outline";
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
                        perform_action = "script.play_on_repeat_on_alarm_clock";
                      };
                    };
                    item2.card = {
                      type = "custom:button-card";
                      entity = "media_player.office";
                      icon = "mdi:monitor";
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
                        perform_action = "script.play_on_repeat_on_office_nest";
                      };
                    };
                    item3.card = {
                      type = "custom:button-card";
                      entity = "media_player.kitchen";
                      icon = "mdi:silverware-variant";
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
                        perform_action = "script.play_on_repeat_on_kitchen_nest";
                      };
                    };
                    item4.card = {
                      type = "custom:button-card";
                      entity = "media_player.bathroom";
                      icon = "mdi:paper-roll-outline";
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
                        perform_action = "script.play_on_repeat_on_bathroom_nest";
                      };
                    };
                    item5.card = {
                      type = "custom:button-card";
                      entity = "media_player.spare_room";
                      icon = "mdi:desk";
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
                        perform_action = "script.play_on_repeat_on_guest_room_nest";
                      };
                    };
                    item6.card = {
                      type = "custom:button-card";
                      entity = "media_player.everywhere";
                      icon = "mdi:home-outline";
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
                        perform_action = "script.play_on_repeat_on_nest_party";
                      };
                    };
                    item7.card = {
                      type = "custom:button-card";
                      entity = "media_player.living_room";
                      icon = "mdi:sofa-outline";
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
                        perform_action = "script.play_on_repeat_on_living_room_nest";
                      };
                    };
                  };
                }
              ];
            })
          ];
        })

        {
          type = "iframe";
          url = "https://music.racci.dev";
          aspect_ratio = "50%";
          grid_options = {
            columns = "full";
            rows = 8;
          };
        }
      ];
      column_span = 2;
      visibility = [ condition.mobileOnly ];
    })
    (mkGridSection {
      cards = [
        {
          type = "conditional";
          conditions = [
            {
              condition = "state";
              entity = "input_boolean.music_player_idle_helper";
              state = "on";
            }
            {
              condition = "state";
              entity = "media_player.music";
              state_not = "off";
            }
            {
              condition = "state";
              entity = "media_player.music";
              state_not = "standby";
            }
            condition.mobileOnly
          ];
          card = {
            type = "vertical-stack";
            cards = [
              {
                square = true;
                columns = 7;
                type = "grid";
                cards = [
                  {
                    type = "custom:button-card";
                    entity = "media_player.everywhere";
                    icon = "mdi:home-outline";
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
                      data.source_player = ''
                        [[[
                          if (states['sensor.music_room'].state == "Living Room") return "media_player.living_room";
                          else if (states['sensor.music_room'].state == "Kitchen") return "media_player.kitchen";
                          else if (states['sensor.music_room'].state == "Bathroom") return "media_player.bathroom_2";
                          else if (states['sensor.music_room'].state == "Bedroom") return "media_player.bedroom_speaker";
                          else if (states['sensor.music_room'].state == "Spare Room") return "media_player.spare_room";
                          else if (states['sensor.music_room'].state == "Everywhere") return "media_player.everywhere";
                          else return "";
                        ]]]
                      '';
                      target.entity_id = "media_player.everywhere";
                      haptic = "success";
                    };
                    double_tap_action = {
                      action = "call-service";
                      service = "script.play_on_repeat_on_nest_party";
                      haptic = "success";
                    };
                    styles.card = [
                      { border-radius = "12px"; }
                      { background-color = "var(--teal)"; }
                    ];
                    styles.icon = [ { color = "var(--black)"; } ];
                  }
                  {
                    type = "custom:button-card";
                    entity = "media_player.living_room";
                    icon = "mdi:sofa-outline";
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
                      data.source_player = ''
                        [[[
                          if (states['sensor.music_room'].state == "Living Room") return "media_player.living_room";
                          else if (states['sensor.music_room'].state == "Kitchen") return "media_player.kitchen";
                          else if (states['sensor.music_room'].state == "Bathroom") return "media_player.bathroom_2";
                          else if (states['sensor.music_room'].state == "Bedroom") return "media_player.bedroom_speaker";
                          else if (states['sensor.music_room'].state == "Spare Room") return "media_player.spare_room";
                          else if (states['sensor.music_room'].state == "Everywhere") return "media_player.everywhere";
                          else return "";
                        ]]]
                      '';
                      target.entity_id = "media_player.living_room_nest_2";
                      haptic = "success";
                    };
                    double_tap_action = {
                      action = "call-service";
                      service = "script.play_on_repeat_on_living_room_nest";
                      haptic = "success";
                    };
                    styles.card = [
                      { border-radius = "12px"; }
                      { background-color = "var(--green)"; }
                    ];
                    styles.icon = [ { color = "var(--black)"; } ];
                  }
                  {
                    type = "custom:button-card";
                    entity = "media_player.bed_room";
                    icon = "mdi:bed";
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
                      data.source_player = ''
                        [[[
                          if (states['sensor.music_room'].state == "Living Room") return "media_player.living_room";
                          else if (states['sensor.music_room'].state == "Kitchen") return "media_player.kitchen";
                          else if (states['sensor.music_room'].state == "Bathroom") return "media_player.bathroom_2";
                          else if (states['sensor.music_room'].state == "Bedroom") return "media_player.bedroom_speaker";
                          else if (states['sensor.music_room'].state == "Spare Room") return "media_player.spare_room";
                          else if (states['sensor.music_room'].state == "Everywhere") return "media_player.everywhere";
                          else return "";
                        ]]]
                      '';
                      target.entity_id = "media_player.bedroom_speakers";
                      haptic = "success";
                    };
                    double_tap_action = {
                      action = "call-service";
                      service = "script.play_on_repeat_on_alarm_clock";
                      haptic = "success";
                    };
                    styles.card = [
                      { border-radius = "12px"; }
                      { background-color = "var(--blue)"; }
                    ];
                    styles.icon = [ { color = "var(--black)"; } ];
                  }
                  {
                    type = "custom:button-card";
                    entity = "media_player.kitchen";
                    icon = "mdi:silverware-variant";
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
                      data.source_player = ''
                        [[[
                          if (states['sensor.music_room'].state == "Living Room") return "media_player.living_room";
                          else if (states['sensor.music_room'].state == "Kitchen") return "media_player.kitchen";
                          else if (states['sensor.music_room'].state == "Bathroom") return "media_player.bathroom_2";
                          else if (states['sensor.music_room'].state == "Bedroom") return "media_player.bedroom_speaker";
                          else if (states['sensor.music_room'].state == "Spare Room") return "media_player.spare_room";
                          else if (states['sensor.music_room'].state == "Everywhere") return "media_player.everywhere";
                          else return "";
                        ]]]
                      '';
                      target.entity_id = "media_player.kitchen";
                      haptic = "success";
                    };
                    double_tap_action = {
                      action = "call-service";
                      service = "script.play_on_repeat_on_kitchen_nest";
                      haptic = "success";
                    };
                    styles.card = [
                      { border-radius = "12px"; }
                      { background-color = "var(--yellow)"; }
                    ];
                    styles.icon = [ { color = "var(--black)"; } ];
                  }
                  {
                    type = "custom:button-card";
                    entity = "media_player.bathroom";
                    icon = "mdi:paper-roll-outline";
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
                      data.source_player = ''
                        [[[
                          if (states['sensor.music_room'].state == "Living Room") return "media_player.living_room";
                          else if (states['sensor.music_room'].state == "Kitchen") return "media_player.kitchen";
                          else if (states['sensor.music_room'].state == "Bathroom") return "media_player.bathroom_2";
                          else if (states['sensor.music_room'].state == "Bedroom") return "media_player.bedroom_speaker";
                          else if (states['sensor.music_room'].state == "Spare Room") return "media_player.spare_room";
                          else if (states['sensor.music_room'].state == "Everywhere") return "media_player.everywhere";
                          else return "";
                        ]]]
                      '';
                      target.entity_id = "media_player.bathroom";
                      haptic = "success";
                    };
                    double_tap_action = {
                      action = "call-service";
                      service = "script.play_on_repeat_on_bathroom_nest";
                      haptic = "success";
                    };
                    styles.card = [
                      { border-radius = "12px"; }
                      { background-color = "var(--purple)"; }
                    ];
                    styles.icon = [ { color = "var(--black)"; } ];
                  }
                  {
                    type = "custom:button-card";
                    entity = "media_player.spare_room";
                    icon = "mdi:desk";
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
                      data.source_player = ''
                        [[[
                          if (states['sensor.music_room'].state == "Living Room") return "media_player.living_room";
                          else if (states['sensor.music_room'].state == "Kitchen") return "media_player.kitchen";
                          else if (states['sensor.music_room'].state == "Bathroom") return "media_player.bathroom_2";
                          else if (states['sensor.music_room'].state == "Bedroom") return "media_player.bedroom_speaker";
                          else if (states['sensor.music_room'].state == "Spare Room") return "media_player.spare_room";
                          else if (states['sensor.music_room'].state == "Everywhere") return "media_player.everywhere";
                          else return "";
                        ]]]
                      '';
                      target.entity_id = "media_player.spare_room";
                      haptic = "success";
                    };
                    double_tap_action = {
                      action = "call-service";
                      service = "script.play_on_repeat_on_guest_room_nest";
                      haptic = "success";
                    };
                    styles.card = [
                      { border-radius = "12px"; }
                      { background-color = "var(--orange)"; }
                    ];
                    styles.icon = [ { color = "var(--black)"; } ];
                  }
                ];
              }
              {
                type = "custom:swipe-card";
                card_width = "100%";
                parameters = {
                  centeredSlides = true;
                  slidesPerView = "auto";
                  spaceBetween = 16;
                  initialSlide = 0;
                };
                cards = [
                  {
                    type = "custom:button-card";
                    entity = "media_player.music";
                    template = "media_player";
                  }
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
                        entity = "media_player.everywhere";
                        state_not = "playing";
                      }
                      {
                        condition = "state";
                        entity = "sensor.music_room";
                        state_not = "Living Room";
                      }
                      {
                        condition = "or";
                        conditions = [
                          {
                            condition = "state";
                            entity = "media_player.living_room";
                            state = "paused";
                          }
                          {
                            condition = "state";
                            entity = "media_player.living_room";
                            state = "playing";
                          }
                        ];
                      }
                    ];
                    card = {
                      type = "custom:button-card";
                      entity = "media_player.living_room";
                      template = "media_player";
                      variables.room = "Living Room";
                      variables.icon_1 = "<ha-icon icon=\"mdi:arrow-down\"></ha-icon>";
                    };
                  }
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
                        entity = "media_player.everywhere";
                        state_not = "playing";
                      }
                      {
                        condition = "state";
                        entity = "sensor.music_room";
                        state_not = "Kitchen";
                      }
                      {
                        condition = "or";
                        conditions = [
                          {
                            condition = "state";
                            entity = "media_player.kitchen";
                            state = "paused";
                          }
                          {
                            condition = "state";
                            entity = "media_player.kitchen";
                            state = "playing";
                          }
                        ];
                      }
                    ];
                    card = {
                      type = "custom:button-card";
                      entity = "media_player.kitchen";
                      template = "media_player";
                      variables.room = "Kitchen";
                      variables.icon_1 = "<ha-icon icon=\"mdi:arrow-down\"></ha-icon>";
                    };
                  }
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
                        entity = "media_player.everywhere";
                        state_not = "playing";
                      }
                      {
                        condition = "state";
                        entity = "sensor.music_room";
                        state_not = "Bathroom";
                      }
                      {
                        condition = "or";
                        conditions = [
                          {
                            condition = "state";
                            entity = "media_player.bathroom";
                            state = "paused";
                          }
                          {
                            condition = "state";
                            entity = "media_player.bathroom";
                            state = "playing";
                          }
                        ];
                      }
                    ];
                    card = {
                      type = "custom:button-card";
                      entity = "media_player.bathroom";
                      template = "media_player";
                      variables.room = "Bathroom";
                      variables.icon_1 = "<ha-icon icon=\"mdi:arrow-down\"></ha-icon>";
                    };
                  }
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
                        entity = "media_player.everywhere";
                        state_not = "playing";
                      }
                      {
                        condition = "state";
                        entity = "sensor.music_room";
                        state_not = "Bedroom";
                      }
                      {
                        condition = "or";
                        conditions = [
                          {
                            condition = "state";
                            entity = "media_player.bedroom_nest_music_assistant";
                            state = "paused";
                          }
                          {
                            condition = "state";
                            entity = "media_player.bedroom_nest_music_assistant";
                            state = "playing";
                          }
                        ];
                      }
                    ];
                    card = {
                      type = "custom:button-card";
                      entity = "media_player.bedroom_speakers";
                      template = "media_player";
                      variables.room = "Bedroom";
                      variables.icon_1 = "<ha-icon icon=\"mdi:arrow-down\"></ha-icon>";
                    };
                  }
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
                        entity = "media_player.everywhere";
                        state_not = "playing";
                      }
                      {
                        condition = "state";
                        entity = "sensor.music_room";
                        state_not = "Spare Room";
                      }
                      {
                        condition = "or";
                        conditions = [
                          {
                            condition = "state";
                            entity = "media_player.spare_room";
                            state = "paused";
                          }
                          {
                            condition = "state";
                            entity = "media_player.spare_room";
                            state = "playing";
                          }
                        ];
                      }
                    ];
                    card = {
                      type = "custom:button-card";
                      entity = "media_player.spare_room";
                      template = "media_player";
                      variables.room = "Spare Room";
                      variables.icon_1 = "<ha-icon icon=\"mdi:arrow-down\"></ha-icon>";
                    };
                  }
                ];
              }
            ];
          };
        }
      ];
    })
  ];
}
