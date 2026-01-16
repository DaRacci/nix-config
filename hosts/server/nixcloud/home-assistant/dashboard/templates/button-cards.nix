{ lib, ... }:
with (import ../lib.nix { inherit lib; });
{
  imports = [
    ../components/button-cards/media_player.nix
  ];

  setup = {
    state = [
      {
        value = "unavailable";
        icon = "mdi:alert-circle-outline";
        styles = {
          state.text-decoration = "line-through";
          label.text-decoration = "line-through";
        };
      }
    ];
    styles = {
      name.font-family = null;
      label.font-family = null;
      state.font-family = null;
    };
  };

  nav_button_small = {
    template = "setup";
    variables = {
      navigation_path = "home";
      icon_on = entity.icon;
      icon_off = entity.icon;
      state_on = "on";
      state_off = "off";
      background_color_on = "var(--red)";
      background_color_off = "var(--green)";
      color_on = "var(--black)";
      color_off = "var(--black)";
    };
    type = "custom:button-card";
    inherit (entity) icon;
    show_label = true;
    tap_action = {
      action = "navigate";
      navigation_path = "[[[ return variables.navigation_path ]]]";
      haptic = "success";
    };
    hold_action.action = "more-info";
    state = [
      (style.iconState "on")
      (style.iconState "off")
    ];
    custom_fields = {
      icon2 = {
        card = {
          type = "custom:button-card";
          icon = "mdi:arrow-right-bold";
          styles = {
            card = {
              background-color = "var(--contrast1)";
              width = "27px";
              height = "27px";
            };
            icon = {
              width = "15px";
              color = "var(--contrast20)";
            };
          };
        };
      };
    };
    styles = {
      grid = {
        grid-template-areas = ''" l l icon2 " " i n n "'';
        grid-template-columns = "14px 1fr 1fr";
        grid-template-rows = "1fr min-content";
      };
      icon = {
        width = "14px";
        margin-bottom = "5px";
        color = colourOnOff "black" "contrast20";
      };
      img_cell.justify-content = "flex-start";
      name = {
        justify-self = "start";
        font-size = "11px";
        margin-bottom = "2px";
        margin-left = "3px";
        color = colourOnOff "black" "contrast20";
        opacity = 0.7;
      };
      card = {
        height = "75px";
        background-color = colourOnOff "yellow" "contrast2";
        box-shadow = "none";
        border-radius = "24px";
        padding = "12px 0 12px 14px";
        z-index = 1;
      };
      label = {
        justify-self = "start";
        font-size = "20px";
        margin-top = "11px";
        font-weight = 500;
        color = colourOnOff "black" "contrast20";
      };
      custom_fields = {
        icon2 = {
          margin-top = "-20px";
          justify-self = "end";
          align-self = "center";
          width = "24px";
          padding-right = "10px";
          color = colourOnOff "black" "contrast20";
        };
      };
    };
  };

  nav_button_state_small = {
    template = "setup";
    variables = {
      navigation_path = "home";
      icon_on = entity.icon;
      icon_off = entity.icon;
      state_on = "on";
      state_off = "off";
      background_color_on = "var(--red)";
      background_color_off = "var(--green)";
      color_on = "var(--black)";
      color_off = "var(--black)";
    };
    type = "custom:button-card";
    inherit (entity) icon;
    show_label = false;
    show_state = true;

    tap_action = {
      action = "navigate";
      navigation_path = "[[[ return variables.navigation_path ]]]";
      haptic = "success";
    };
    hold_action.action = "more-info";

    state = [
      (style.iconState "on")
      (style.iconState "off")
    ];
    custom_fields = {
      icon2 = {
        card = {
          type = "custom:button-card";
          icon = "mdi:arrow-right-bold";
          styles = {
            card = {
              background-color = "var(--contrast1)";
              width = "27px";
              height = "27px";
            };
            icon = {
              width = "15px";
              color = "var(--contrast20)";
            };
          };
        };
      };
    };
    styles = {
      grid = {
        grid-template-areas = ''" s s icon2 " " i n n "'';
        grid-template-columns = "14px 1fr 1fr";
        grid-template-rows = "1fr min-content";
      };
      icon = {
        width = "14px";
        margin-bottom = "5px";
        color = colourOnOff "black" "contrast20";
      };
      img_cell.justify-content = "flex-start";
      name = {
        justify-self = "start";
        font-size = "11px";
        margin-bottom = "2px";
        margin-left = "3px";
        color = colourOnOff "black" "contrast20";
        opacity = 0.7;
      };
      card = {
        height = "75px";
        background-color = colourOnOff "yellow" "contrast2";
        box-shadow = "none";
        border-radius = "24px";
        padding = "12px 0 12px 14px";
        z-index = 1;
      };
      state = {
        justify-self = "start";
        font-size = "20px";
        margin-top = "11px";
        font-weight = 500;
        color = colourOnOff "black" "contrast20";
      };
      custom_fields = {
        icon2 = {
          margin-top = "-20px";
          justify-self = "end";
          align-self = "center";
          width = "24px";
          padding-right = "10px";
          color = colourOnOff "black" "contrast20";
        };
      };
    };
  };

  custom_card_alarm_bottom = {
    template = "setup";
    entity = "sensor.wake_time_1";
    show_label = false;
    name = "[[[ return states[\"sensor.time\"].state ]]]";
    show_state = false;
    show_entity_picture = false;
    icon = "mdi:alarm";
    styles = {
      grid = {
        grid-template-areas = ''"i n snooze stop"'';
        grid-template-columns = "min-content min-content 1fr 1fr";
        grid-template-rows = "min-content";
        column-gap = 15;
      };
      icon = {
        width = "60px";
        color = "var(--red)";
        animation = "alarm 0.8s ease infinite";
      };
      card = {
        padding = "15px 15px 15px 15px";
        height = "180px";
        width = "100vw";
        overflow = "hidden";
        position = ''
          [[[
            if (states["input_boolean.debug_rounded"].state == "on") {
              return 'static'
            } else {
              return 'fixed'
            }
          ]]]
        '';
        margin = 0;
        bottom = 0;
        left = 0;
        z-index = 2;
        border-radius = "20px 20px 0px 0px";
        box-shadow = "rgba(14, 30, 37, 0.12) 0px 2px 4px 0px, rgba(14, 30, 37, 0.32) 0px 2px 16px 0px;";
      };
      img_cell = {
        background = "none";
        border-radius = "10px";
        width = "50px";
        height = "50px";
        justify-self = "start";
        align-self = "start";
        left = "10px";
      };
      name = {
        font-size = "28px";
        font-weight = 700;
        justify-self = "start";
        align-self = "center";
        padding-left = "10px";
      };
      custom_fields = {
        snooze.justify-self = "end";
        stop.justify-self = "end";
      };
    };
    extra_styles = ''
      @keyframes alarm {
        0%, 80%, 100% { transform: translateY(0); }
        10% { transform: translateY(-2px) rotate(-8deg); }
        20% { transform: translateY(-2px) rotate(9deg); }
        30% { transform: translateY(-2px) rotate(-5deg); }
        40% { transform: translateY(-2px) rotate(4deg); }
        50% { transform: translateY(0); }
        60% { transform: translateY(-1.2px) }
      }
    '';
    custom_fields = {
      snooze = {
        card = {
          type = "custom:button-card";
          icon = "mdi:alarm-snooze";
          entity = "input_boolean.alarm_snoozed";
          name = "Snooze";
          show_name = true;
          show_icon = true;
          tap_action = {
            action = "toggle";
          };
          styles = {
            grid = {
              grid-template-areas = "\"i n\"";
              grid-template-columns = "min-content min-content";
            };
            card = {
              padding = "4px";
              background = "var(--orange)";
              border-radius = "24px";
              width = "90px";
            };
            img_cell = {
              justify-self = "start";
              width = "25px";
              height = "25px";
              background = "var(--contrast1)";
              border-radius = "100%";
            };
            name = {
              font-size = "12px";
              color = "var(--black)";
              font-weight = 500;
              justify-self = "start";
              align-self = "center";
              padding-left = "5px";
            };
            icon = {
              width = "14px";
              color = "var(--orange)";
              align-self = "center";
            };
          };
        };
      };
      stop = {
        card = {
          type = "custom:button-card";
          icon = "mdi:alarm-off";
          entity = "input_boolean.sound_alarm_is_running";
          name = "STOP";
          show_name = true;
          show_icon = true;
          tap_action.action = "toggle";
          styles = {
            grid = {
              grid-template-areas = ''"i n"'';
              grid-template-columns = "min-content min-content";
            };
            card = {
              padding = "4px";
              background = "var(--red)";
              border-radius = "24px";
              width = "90px";
              margin-right = "5px";
            };
            img_cell = {
              justify-self = "start";
              width = "25px";
              height = "25px";
              background = "var(--contrast1)";
              border-radius = "100%";
            };
            name = {
              font-size = "12px";
              color = "var(--black)";
              font-weight = 500;
              justify-self = "start";
              align-self = "center";
              padding-left = "5px";
            };
            icon = {
              width = "14px";
              color = "var(--red)";
              align-self = "center";
            };
          };
        };
      };
    };
  };

  custom_card_mediaplayer_bottom = {
    template = "setup";
    show_label = true;
    name = ''
      [[[
        if (states[ entity.entity_id ].attributes.active_child == "media_player.playstation_5") {
          return states["sensor.ps5_343_activity"].attributes.players
        } else if (states[ entity.entity_id ].attributes.active_child == "media_player.steam_jlnbln") {
          return 'jlnbln'
        } else if (states[ entity.entity_id ].attributes.active_child == "media_player.plex_bedroom") {
          return states[ entity.entity_id ].attributes.media_series_title
        } else {
          if (states[ entity.entity_id ].attributes.media_artist != null ) {
            return states[ entity.entity_id ].attributes.media_artist
          } else {
            return "Streaming"
          }
        }
      ]]]
    '';
    label = "[[[ return states[ entity.entity_id ].attributes.media_title ]]]";
    show_state = false;
    show_entity_picture = true;
    entity_picture = ''
      [[[
        if (states[ entity.entity_id ].attributes.active_child == "media_player.playstation_5") {
          return states["sensor.ps5_343_activity"].attributes.title_image
        } else if (states[ entity.entity_id ].attributes.active_child == "media_player.apple_tv_4k_2") {
          if (states[ entity.entity_id ].attributes.media_artist == "Rocket League Esports") {
            return '/local/images/rlesports.jpg';
          } else {
            return states["media_player.apple_tv_4k_2"].attributes.entity_picture
          }
        } else if (states[ entity.entity_id ].attributes.active_child == "media_player.steam_jlnbln") {
          return states["sensor.steam_76561197981585794"].attributes.game_image_main
        } else if (states[ entity.entity_id ].attributes.active_child == "media_player.plex_bedroom") {
          return states["media_player.plex_bedroom"].attributes.entity_picture
        } else if (states[ entity.entity_id ].attributes.active_child == "media_player.music") {
          if (states["media_player.music"].attributes.active_child == "media_player.bedroom_nest_music_assistant") {
            return states["media_player.bedroom_speakers"].attributes.entity_picture
          } else {
            return states[ entity.entity_id ].attributes.entity_picture
          }
        } else if (states[ entity.entity_id ].attributes.active_child == "media_player.audiobook") {
          if (states["input_select.audiobook"].state == "Harry Potter") {
            if (states["input_number.hp_book"].state == 1.0) {
              return "/local/images/HP_1.jpg";
            } else if (states["input_number.hp_book"].state == 2.0) {
              return "/local/images/HP_2.jpg";
            } else if (states["input_number.hp_book"].state == 3.0) {
              return "/local/images/HP_3.jpg";
            } else if (states["input_number.hp_book"].state == 4.0) {
              return "/local/images/HP_4.jpg";
            } else if (states["input_number.hp_book"].state == 5.0) {
              return "/local/images/HP_5.jpg";
            } else if (states["input_number.hp_book"].state == 6.0) {
              return "/local/images/HP_6.jpg";
            } else if (states["input_number.hp_book"].state == 7.0) {
              return "/local/images/HP_7.jpg";
            }
          }
        } else {
          return states[ entity.entity_id ].attributes.entity_picture
        }
      ]]]
    '';
    icon = ''
      [[[
        if (states[ entity.entity_id ].attributes.active_child == "media_player.playstation_5") {
          return 'mdi:sony-playstation'
        } else if (states[ entity.entity_id ].attributes.app_name == "YouTube") {
          return 'mdi:youtube-tv'
        } else if (states[ entity.entity_id ].attributes.app_name == "Netflix") {
          return 'mdi:netflix'
        } else if (states[ entity.entity_id ].attributes.app_name == "Plex") {
          return 'mdi:plex'
        } else {
          return 'mdi:television-guide'
        }
      ]]]
    '';
    styles = {
      grid = {
        grid-template-areas = ''"i play_state button" "i l button" "i n button" "bar bar bar"'';
        grid-template-columns = "min-content";
        grid-template-rows = "min-content min-content min-content";
        column-gap = 15;
      };
      icon = {
        width = 60;
        height = 60;
        color = "var(--red)";
      };
      card = {
        padding = "15px 15px 15px 15px";
        height = 180;
        width = "100vw";
        overflow = "hidden";
        position = ''
          [[[
            if (states["input_boolean.debug_rounded"].state == "on") {
              return 'static'
            } else {
              return 'fixed'
            }
          ]]]
        '';
        margin = 0;
        bottom = 0;
        left = 0;
        z-index = 2;
        border-radius = "20px 20px 0px 0px";
        box-shadow = "rgba(14, 30, 37, 0.12) 0px 2px 4px 0px, rgba(14, 30, 37, 0.32) 0px 2px 16px 0px";
      };
      img_cell = {
        background = "none";
        border-radius = 10;
        width = 60;
        height = 60;
        justify-self = "start";
        align-self = "start";
        left = 20;
      };
      entity_picture.object-fit = "cover";
      state = {
        font-size = 10;
        justify-self = "start";
        align-self = "start";
        color = "var(--contrast10)";
        padding-right = 25;
      };
      name = {
        font-size = 11;
        justify-self = "start";
        align-self = "start";
        padding-right = 20;
        animation = "my-animation 15s linear infinite";
      };
      label = {
        justify-self = "start";
        align-self = "end";
        font-weight = 700;
        padding-right = 20;
        font-size = 13;
        margin-top = "-5px";
      };
      custom_fields = {
        button = {
          justify-self = "end";
          align-self = "center";
          padding-right = 20;
          padding-top = 7;
        };
        play_state = {
          font-size = 10;
          justify-self = "start";
          align-self = "start";
          color = "var(--contrast14)";
          padding-right = 21;
          padding-top = 10;
        };
        progress = {
          background-color = "var(--contrast10)";
          position = "absolute";
          top = "unset";
          bottom = 90;
          left = 40;
          height = 2;
          width = "80%";
        };
        bar = {
          background-color = "var(--green)";
          position = "absolute";
          bottom = 90;
          left = 40;
          top = "unset";
          height = 2;
          z-index = 1;
          transition = "1s ease-out";
        };
      };
    };
    custom_fields = {
      button.card = {
        type = "custom:button-card";
        icon = "mdi:play";
        entity = "[[[ return entity.entity_id ]]]";
        show_name = false;
        tap_action = {
          action = "call-service";
          service = "media_player.media_play_pause";
          target.entity_id = "[[[ return entity.entity_id ]]]";
        };
        styles = {
          card = {
            overflow = "visible";
            background = "var(--contrast6)";
            "border-radius" = 10;
          };
          icon = {
            width = 17;
            color = "var(--contrast16)";
          };
          img_cell = {
            padding = 10;
            width = 20;
          };
        };
        state = [
          {
            value = "playing";
            icon = ''
              [[[
                if (states[entity.entity_id].attributes.active_child == "media_player.playstation_5") {
                  return 'mdi:sony-playstation'
                } else if (states[entity.entity_id].attributes.active_child == "media_player.steam_jlnbln") {
                  return 'mdi:steam'
                } else {
                  return 'mdi:pause'
                }
              ]]]
            '';
          }
        ];
      };
      play_state = ''
        [[[
          if (states[entity.entity_id].attributes.active_child == "media_player.spotify_james") {
            return states[entity.entity_id].state + " - " + states[entity.entity_id].attributes.source
          } else if (states[entity.entity_id].attributes.active_child == "media_player.playstation_5") {
            return states[entity.entity_id].state + " - Playstation 5"
          } else if (states[entity.entity_id].attributes.active_child == "media_player.audiobook") {
            return states[entity.entity_id].state + " - Alarm Clock"
          } else if (states[entity.entity_id].attributes.active_child == "media_player.plex_bedroom") {
            return states[entity.entity_id].state + " - Bedroom TV"
          } else if (states[entity.entity_id].attributes.active_child == "media_player.steam_jlnbln") {
            return states[entity.entity_id].state + " - Steam"
          } else if (states[entity.entity_id].attributes.active_child == "media_player.apple_tv_4k_2") {
            return states[entity.entity_id].state + " - " + states[entity.entity_id].attributes.app_name
          } else {
            return states[entity.entity_id].state + " - " + states["sensor.music_room"].state
          }
        ]]]
      '';
      bar = ''
        [[[
          if (entity.attributes.media_position !== undefined) {
          setTimeout(() => {
            let elt = this.shadowRoot,
                card = elt.getElementById('card'),
                container = elt.getElementById('container'),
                bar = elt.getElementById('bar');
            if (elt && card && container && bar) {
                card.insertBefore(bar, container);
                  function update() {
                    let mediaPositionUpdatedAt = entity.attributes.media_position_updated_at,
                        mediaPosition = entity.attributes.media_position,
                        mediaDuration = entity.attributes.media_duration,
                        mediaContentType = entity.attributes.media_content_type;
                    let percentage = entity.state === 'paused'
                      ? (mediaPosition / mediaDuration * 80)
                      : entity.state === 'playing'
                        ? (((Date.now() / 1000) - (new Date(mediaPositionUpdatedAt).getTime() / 1000) + mediaPosition) / mediaDuration * 80)
                        : 0;
                    bar.style.width = percentage.toFixed(1) + '%';
                    requestAnimationFrame(update);
                  }
                  requestAnimationFrame(update);
            }
          }, 0);
          return ' ';}
        ]]]
      '';
    };
  };

  custom_card_timer_bottom = {
    template = "setup";
    type = "custom:button-card";
    entity = ''
      [[[
        if (states["sensor.kitchen_timer"].state == "on") {
          return 'sensor.kitchen_timer'
        } else if (states["sensor.living_room_timer"].state == "on") {
          return 'sensor.living_room_timer'
        } else if (states["sensor.office_timer"].state == "on") {
          return 'sensor.office_timer'
        } else if (states["sensor.bed_room_timer"].state == "on") {
          return 'sensor.bed_room_timer'
        } else if (states["sensor.bathroom_timer"].state == "on") {
          return 'sensor.bathroom_timer'
        } else {
          return 'sensor.kitchen_timer'
        }
      ]]]
    '';
    show_name = true;
    show_icon = false;
    show_label = false;
    show_state = false;
    tap_action.action = "more-info";
    hold_action.action = "more-info";
    custom_fields = {
      bar = ''
        [[[
          var color = "var(--green)";
          var state = 100 - states[ entity.entity_id ].attributes.remaining_perc;
          if (state < 10) color = "var(--red)";
          else if (state < 50) color = "var(--yellow)";
          else if (state < 90) color = "var(--orange)";
          return `
          <div>
          <div style="background:''${color}; height: 12px; width:''${state}%">
          </div>
          </div>`
        ]]]
      '';
      rem = {
        card = {
          type = "custom:button-card";
          entity = entity.id;
          name = template.remainingTime;
          show_icon = false;
          styles = {
            card = {
              width = "min";
              background = "none";
              overflow = "visible";
            };
            name = {
              font-size = 14;
              margin-top = 6;
              font-weight = 600;
              color = "var(--contrast20)";
            };
          };
        };
      };
      icon1 = ''[[[ return '<ha-icon icon=" "mdi:timer-outline" "></ha-icon>'; ]]]'';
    };
    styles = {
      grid = {
        grid-template-areas = ''"rem icon1" "n icon2" "bar bar"'';
        grid-template-rows = "min-content min-content min-content";
        grid-template-columns = "60% 40%";
      };
      card = {
        padding = "15px 35px 15px 35px";
        background = "var(--contrast2)";
        height = template.stateIfElse {
          entity = "media_player.music_and_tv";
          states = [
            "playing"
            "paused"
          ];
          ifTrue = "280px";
          ifFalse = "180px";
        };
        width = "100vw";
        overflow = "hidden";
        position = template.stateOnIfElse {
          entity = "input_boolean.debug_rounded";
          valueOn = "static";
          valueOff = "fixed";
        };
        margin = 0;
        bottom = 0;
        left = 0;
        z-index = 1;
        border-radius = "20px 20px 0px 0px";
        box-shadow = "rgba(14, 30, 37, 0.12) 0px 2px 4px 0px, rgba(14, 30, 37, 0.32) 0px 2px 16px 0px";
      };
      img_cell = {
        position = "absolute";
        top = "20%";
        left = "40%";
        overflow = "visible";
      };
      label = {
        text-align = "left";
        font-size = 18;
        font-weight = 500;
        justify-self = "start";
        align-self = "start";
        overflow = "visible";
        color = "var(--contrast20)";
      };
      name = {
        text-align = "left";
        font-size = 12;
        justify-self = "start";
        align-self = "start";
        overflow = "visible";
        color = "var(--contrast20)";
      };
      custom_fields = {
        bar = {
          justify-self = "start";
          align-self = "start";
          margin-top = 10;
          width = "100%";
          height = template.stateOnIfElse {
            entity = "entity.state";
            valueOn = "12px";
            valueOff = "0px";
          };
          background = "var(--contrast1)";
          border-radius = 24;
        };
        rem = {
          justify-self = "start";
          font-size = 14;
          font-weight = 600;
          align-self = "end";
          height = template.stateOnIfElse {
            entity = "entity.state";
            valueOn = "27px";
            valueOff = "0px";
          };
        };
        icon1 = {
          justify-self = "end";
          align-self = "start";
          width = 24;
          color = "var(--contrast20)";
        };
      };

      hold_action.action = "more-info";
    };
  };
}
