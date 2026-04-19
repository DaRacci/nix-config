{ lib, ... }:
with (import ../lib.nix { inherit lib; });
{
  setup = {
    state = [
      {
        value = "unavailable";
        icon = "mdi:alert-circle-outline";
        styles = mkStyles {
          state = {
            text-decoration = "line-through";
          };
          label = {
            text-decoration = "line-through";
          };
        };
      }
    ];
    styles = mkStyles {
      name = {
        font-family = null;
      };
      label = {
        font-family = null;
      };
      state = {
        font-family = null;
      };
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
          styles = mkStyles {
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
    styles = mkStyles {
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
      img_cell = {
        justify-content = "flex-start";
      };
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
          styles = mkStyles {
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
    styles = mkStyles {
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
      img_cell = {
        justify-content = "flex-start";
      };
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
    styles = mkStyles {
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
        position = jsMatch {
          value = ''states["${entities.inputBooleans.debugRounded}"].state'';
          cases = [
            {
              match = "on";
              ret = "'static'";
            }
          ];
          default = "'fixed'";
        };
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
        snooze = {
          justify-self = "end";
        };
        stop = {
          justify-self = "end";
        };
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
          entity = entities.inputBooleans.alarmSnoozed;
          name = "Snooze";
          show_name = true;
          show_icon = true;
          tap_action = {
            action = "toggle";
          };
          styles = mkStyles {
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
          entity = entities.inputBooleans.soundAlarmRunning;
          name = "STOP";
          show_name = true;
          show_icon = true;
          tap_action.action = "toggle";
          styles = mkStyles {
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
        const child = states[entity.entity_id].attributes.active_child;
        if (child === "media_player.playstation_5") return 'mdi:sony-playstation';
        const app = states[entity.entity_id].attributes.app_name;
        if (app === "YouTube") return 'mdi:youtube-tv';
        if (app === "Netflix") return 'mdi:netflix';
        if (app === "Plex") return 'mdi:plex';
        return 'mdi:television-guide';
      ]]]
    '';
    styles = mkStyles {
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
        position = jsMatch {
          value = ''states["${entities.inputBooleans.debugRounded}"].state'';
          cases = [
            {
              match = "on";
              ret = "'static'";
            }
          ];
          default = "'fixed'";
        };
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
      entity_picture = {
        object-fit = "cover";
      };
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
        styles = mkStyles {
          card = {
            overflow = "visible";
            background = "var(--contrast6)";
            border-radius = 10;
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
            icon = jsMatch {
              value = "states[entity.entity_id].attributes.active_child";
              cases = [
                {
                  match = "media_player.playstation_5";
                  ret = "'mdi:sony-playstation'";
                }
                {
                  match = "media_player.steam_jlnbln";
                  ret = "'mdi:steam'";
                }
              ];
              default = "'mdi:pause'";
            };
          }
        ];
      };
      play_state = jsMatch {
        value = "states[entity.entity_id].attributes.active_child";
        cases = [
          {
            match = "media_player.spotify_james";
            ret = ''states[entity.entity_id].state + " - " + states[entity.entity_id].attributes.source'';
          }
          {
            match = "media_player.playstation_5";
            ret = ''states[entity.entity_id].state + " - Playstation 5"'';
          }
          {
            match = "media_player.audiobook";
            ret = ''states[entity.entity_id].state + " - Alarm Clock"'';
          }
          {
            match = "media_player.plex_bedroom";
            ret = ''states[entity.entity_id].state + " - Bedroom TV"'';
          }
          {
            match = "media_player.steam_jlnbln";
            ret = ''states[entity.entity_id].state + " - Steam"'';
          }
          {
            match = "media_player.apple_tv_4k_2";
            ret = ''states[entity.entity_id].state + " - " + states[entity.entity_id].attributes.app_name'';
          }
        ];
        default = ''states[entity.entity_id].state + " - " + states["${entities.sensors.musicRoom}"].state'';
      };
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

  custom_card_mediaplayer_music = {
    template = "setup";
    show_label = true;
    show_name = true;
    show_entity_picture = true;
    entity_picture = ''
      [[[
        if (entity.attributes.entity_picture == undefined) {
          return '/local/images/abstract-gif-colors.gif';
        } else {
          return entity.attributes.entity_picture;
        }
      ]]]
    '';
    name = "[[[ return entity.attributes.media_title || 'No media' ]]]";
    label = "[[[ return entity.attributes.media_artist || '' ]]]";
    tap_action.action = "more-info";
    styles = mkStyles {
      grid = {
        grid-template-areas = ''"i play_state icon1" "i l l" "i n n" "i buttons buttons" "bar bar bar"'';
        grid-template-columns = "min-content 1fr min-content";
        grid-template-rows = "min-content min-content min-content min-content min-content";
        column-gap = "10px";
      };
      card = {
        border-radius = "24px";
        background-color = "var(--contrast2)";
        box-shadow = "none";
        padding = "15px";
        overflow = "visible";
      };
      entity_picture = {
        border-radius = "12px";
        width = "80px";
        height = "80px";
        object-fit = "cover";
      };
      img_cell = {
        width = "80px";
        height = "80px";
      };
      name = {
        justify-self = "start";
        font-size = "14px";
        font-weight = 700;
        color = "var(--contrast20)";
        white-space = "nowrap";
        overflow = "hidden";
        text-overflow = "ellipsis";
        max-width = "100%";
      };
      label = {
        justify-self = "start";
        font-size = "12px";
        font-weight = 500;
        color = "var(--contrast14)";
      };
      custom_fields = {
        play_state = {
          justify-self = "start";
          font-size = "10px";
          font-weight = 500;
          color = "var(--contrast10)";
          padding-top = "5px";
        };
        icon1 = {
          justify-self = "end";
          color = "var(--contrast14)";
        };
        buttons = {
          justify-self = "start";
          margin-top = "5px";
        };
        progress = {
          background-color = "var(--contrast6)";
          position = "absolute";
          bottom = "15px";
          left = "15px";
          height = "3px";
          width = "calc(100% - 30px)";
          border-radius = "2px";
        };
        bar = {
          background-color = "var(--green)";
          position = "absolute";
          bottom = "15px";
          left = "15px";
          height = "3px";
          z-index = 1;
          border-radius = "2px";
          transition = "1s ease-out";
        };
      };
    };
    custom_fields = {
      play_state = jsMatch {
        value = "entity.state";
        cases = [
          {
            match = "playing";
            ret = "'Playing'";
          }
          {
            match = "paused";
            ret = "'Paused'";
          }
        ];
        default = "entity.state";
      };
      icon1 = "[[[ return variables.icon_1 || '' ]]]";
      progress = " ";
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
                      mediaDuration = entity.attributes.media_duration;
                  let percentage = entity.state === 'paused'
                    ? (mediaPosition / mediaDuration * 93)
                    : entity.state === 'playing'
                      ? (((Date.now() / 1000) - (new Date(mediaPositionUpdatedAt).getTime() / 1000) + mediaPosition) / mediaDuration * 93)
                      : 0;
                  bar.style.width = percentage.toFixed(1) + '%';
                  requestAnimationFrame(update);
                }
                requestAnimationFrame(update);
              }
            }, 0);
            return ' ';
          }
        ]]]
      '';
      buttons.card = {
        type = "custom:button-card";
        styles = mkStyles {
          card = {
            background = "none";
            box-shadow = "none";
            padding = "0";
          };
          grid = {
            grid-template-areas = ''"prev play_pause next"'';
            grid-template-columns = "1fr 1fr 1fr";
            column-gap = "8px";
          };
        };
        custom_fields = {
          prev.card = {
            type = "custom:button-card";
            icon = "mdi:skip-previous";
            entity = "[[[ return entity.entity_id ]]]";
            show_name = false;
            tap_action = {
              action = "call-service";
              service = "media_player.media_previous_track";
              target.entity_id = "[[[ return entity.entity_id ]]]";
            };
            styles = mkStyles {
              card = {
                background = "var(--contrast4)";
                border-radius = "10px";
                padding = "8px";
              };
              icon = {
                width = "16px";
                color = "var(--contrast16)";
              };
            };
          };
          play_pause.card = {
            type = "custom:button-card";
            icon = jsMatch {
              value = "entity.state";
              cases = [
                {
                  match = "playing";
                  ret = "'mdi:pause'";
                }
              ];
              default = "'mdi:play'";
            };
            entity = "[[[ return entity.entity_id ]]]";
            show_name = false;
            tap_action = {
              action = "call-service";
              service = "media_player.media_play_pause";
              target.entity_id = "[[[ return entity.entity_id ]]]";
            };
            styles = mkStyles {
              card = {
                background = "var(--green)";
                border-radius = "10px";
                padding = "8px";
              };
              icon = {
                width = "18px";
                color = "var(--black)";
              };
            };
          };
          next.card = {
            type = "custom:button-card";
            icon = "mdi:skip-next";
            entity = "[[[ return entity.entity_id ]]]";
            show_name = false;
            tap_action = {
              action = "call-service";
              service = "media_player.media_next_track";
              target.entity_id = "[[[ return entity.entity_id ]]]";
            };
            styles = mkStyles {
              card = {
                background = "var(--contrast4)";
                border-radius = "10px";
                padding = "8px";
              };
              icon = {
                width = "16px";
                color = "var(--contrast16)";
              };
            };
          };
        };
      };
    };
    variables = {
      icon_1 = "";
    };
  };

  custom_card_mediaplayer_tv = {
    template = "setup";
    show_label = true;
    show_name = true;
    show_state = true;
    show_entity_picture = true;
    entity_picture = ''
      [[[
        if (entity.attributes.entity_picture == undefined) {
          return '/local/images/tv-placeholder.png';
        } else {
          return entity.attributes.entity_picture;
        }
      ]]]
    '';
    label = ''
      [[[
        if (entity.attributes.app_name) return entity.attributes.app_name;
        else return entity.state;
      ]]]
    '';
    name = ''
      [[[
        if (entity.attributes.active_child == "media_player.playstation_5") {
          return states["sensor.ps5_343_activity"].attributes.players || "Playstation 5";
        } else if (entity.attributes.active_child == "media_player.steam_jlnbln") {
          return "Steam";
        } else if (entity.attributes.media_artist) {
          return entity.attributes.media_artist;
        } else if (entity.attributes.media_title) {
          return entity.attributes.media_title;
        } else {
          return entity.attributes.friendly_name || "TV";
        }
      ]]]
    '';
    state_display = ''
      [[[
        if (entity.attributes.media_title) return entity.attributes.media_title;
        else return "";
      ]]]
    '';
    tap_action.action = "more-info";
    styles = mkStyles {
      grid = {
        grid-template-areas = ''"app_icon l i" "s s s" "n n n"'';
        grid-template-columns = "min-content 1fr min-content";
        grid-template-rows = "min-content min-content min-content";
        column-gap = "10px";
      };
      card = {
        border-radius = "24px";
        background-color = "var(--contrast2)";
        box-shadow = "none";
        padding = "15px";
        overflow = "hidden";
      };
      entity_picture = {
        border-radius = "8px";
        width = "40px";
        height = "40px";
        object-fit = "cover";
      };
      img_cell = {
        width = "40px";
        height = "40px";
        display = "none";
      };
      icon = {
        width = "24px";
        color = "var(--contrast14)";
      };
      label = {
        justify-self = "start";
        align-self = "center";
        font-size = "12px";
        font-weight = 600;
        color = "var(--contrast14)";
      };
      state = {
        justify-self = "start";
        font-size = "14px";
        font-weight = 500;
        color = "var(--contrast16)";
        margin-top = "5px";
      };
      name = {
        justify-self = "start";
        font-size = "16px";
        font-weight = 700;
        color = "var(--contrast20)";
        margin-top = "2px";
        white-space = "nowrap";
        overflow = "hidden";
        text-overflow = "ellipsis";
      };
      custom_fields = {
        app_icon = {
          width = "40px";
          height = "40px";
          border-radius = "8px";
          overflow = "hidden";
        };
        background_cover = {
          position = "absolute";
          top = "0";
          left = "0";
          width = "100%";
          height = "100%";
          opacity = "0.15";
          z-index = "0";
          background-size = "cover";
          background-position = "center";
        };
      };
    };
    custom_fields = {
      app_icon = ''
        [[[
          if (entity.attributes.active_child == "media_player.playstation_5") {
            return '<ha-icon icon="mdi:sony-playstation" style="color: var(--blue); width: 32px; height: 32px;"></ha-icon>';
          } else if (entity.attributes.active_child == "media_player.steam_jlnbln") {
            return '<ha-icon icon="mdi:steam" style="color: var(--contrast20); width: 32px; height: 32px;"></ha-icon>';
          } else if (entity.attributes.active_child == "media_player.plex_bedroom") {
            return '<ha-icon icon="mdi:plex" style="color: var(--orange); width: 32px; height: 32px;"></ha-icon>';
          } else if (entity.attributes.app_name == "YouTube") {
            return '<ha-icon icon="mdi:youtube" style="color: var(--red); width: 32px; height: 32px;"></ha-icon>';
          } else if (entity.attributes.app_name == "Netflix") {
            return '<ha-icon icon="mdi:netflix" style="color: var(--red); width: 32px; height: 32px;"></ha-icon>';
          } else {
            return '<ha-icon icon="mdi:television" style="color: var(--contrast14); width: 32px; height: 32px;"></ha-icon>';
          }
        ]]]
      '';
      background_cover = ''
        [[[
          let bgImage = "";
          if (entity.attributes.active_child == "media_player.playstation_5") {
            bgImage = states["sensor.ps5_343_activity"].attributes.title_image || "";
          } else if (entity.attributes.active_child == "media_player.steam_jlnbln") {
            bgImage = states["sensor.steam_76561197981585794"].attributes.game_image_main || "";
          } else if (entity.attributes.entity_picture) {
            bgImage = entity.attributes.entity_picture;
          }
          if (bgImage) {
            return '<div style="background-image: url(' + bgImage + '); width: 100%; height: 100%; background-size: cover; background-position: center;"></div>';
          }
          return "";
        ]]]
      '';
    };
  };

  custom_card_user = {
    template = "setup";
    show_name = true;
    show_label = true;
    show_icon = false;
    show_entity_picture = false;
    name = ''
      [[[
        var hour = new Date().getHours();
        var greeting = "";
        if (hour >= 5 && hour < 12) greeting = "Good morning";
        else if (hour >= 12 && hour < 17) greeting = "Good afternoon";
        else if (hour >= 17 && hour < 21) greeting = "Good evening";
        else greeting = "Good night";
        var name = entity.attributes.friendly_name || "User";
        return greeting + ", " + name + "!";
      ]]]
    '';
    label = jsMatch {
      value = "entity.state";
      cases = [
        {
          match = "home";
          ret = "'Welcome home'";
        }
      ];
      default = "'You are away'";
    };
    tap_action.action = "more-info";
    styles = mkStyles {
      grid = {
        grid-template-areas = ''"pic n badge" "pic l badge" "one two three"'';
        grid-template-columns = "min-content 1fr min-content";
        grid-template-rows = "min-content min-content min-content";
        column-gap = "10px";
        row-gap = "5px";
      };
      card = {
        border-radius = "24px";
        background-color = "var(--contrast2)";
        box-shadow = "none";
        padding = "15px";
      };
      name = {
        justify-self = "start";
        align-self = "end";
        font-size = "18px";
        font-weight = 700;
        color = "var(--contrast20)";
      };
      label = {
        justify-self = "start";
        align-self = "start";
        font-size = "12px";
        font-weight = 500;
        color = "var(--contrast14)";
      };
      custom_fields = {
        pic = {
          width = "50px";
          height = "50px";
          border-radius = "50%";
          overflow = "hidden";
        };
        badge = {
          justify-self = "end";
          align-self = "center";
        };
        one = {
          justify-self = "start";
          margin-top = "10px";
        };
        two = {
          justify-self = "center";
          margin-top = "10px";
        };
        three = {
          justify-self = "end";
          margin-top = "10px";
        };
      };
    };
    custom_fields = {
      pic = ''
        [[[
          var pic = entity.attributes.entity_picture || "";
          if (pic) {
            return '<img src="' + pic + '" style="width: 50px; height: 50px; border-radius: 50%; object-fit: cover;">';
          }
          return '<ha-icon icon="mdi:account" style="width: 50px; height: 50px;"></ha-icon>';
        ]]]
      '';
      badge = jsMatch {
        value = "entity.state";
        cases = [
          {
            match = "home";
            ret = ''"<ha-icon icon=\"mdi:home\" style=\"color: var(--green); width: 24px; height: 24px;\"></ha-icon>"'';
          }
        ];
        default = ''"<ha-icon icon=\"mdi:home-outline\" style=\"color: var(--contrast10); width: 24px; height: 24px;\"></ha-icon>"'';
      };
      one = ''
        [[[
          var james = states["person.james"];
          if (james) {
            var pic = james.attributes.entity_picture || "";
            var home = james.state == "home";
            var opacity = home ? "1" : "0.4";
            if (pic) {
              return '<img src="' + pic + '" style="width: 30px; height: 30px; border-radius: 50%; object-fit: cover; opacity: ' + opacity + ';">';
            }
          }
          return "";
        ]]]
      '';
      two = ''
        [[[
          var savannah = states["person.savannah"];
          if (savannah) {
            var pic = savannah.attributes.entity_picture || "";
            var home = savannah.state == "home";
            var opacity = home ? "1" : "0.4";
            if (pic) {
              return '<img src="' + pic + '" style="width: 30px; height: 30px; border-radius: 50%; object-fit: cover; opacity: ' + opacity + ';">';
            }
          }
          return "";
        ]]]
      '';
      three = ''
        [[[
          var poppy = states["person.poppy"];
          if (poppy) {
            var pic = poppy.attributes.entity_picture || "";
            var home = poppy.state == "home";
            var opacity = home ? "1" : "0.4";
            if (pic) {
              return '<img src="' + pic + '" style="width: 30px; height: 30px; border-radius: 50%; object-fit: cover; opacity: ' + opacity + ';">';
            }
          }
          return "";
        ]]]
      '';
    };
  };

  custom_card_climate = {
    template = "setup";
    variables = {
      name = "Climate";
      sensor = "";
      open = "Open";
      radius = "24px";
    };
    show_name = true;
    show_label = true;
    show_icon = true;
    show_state = false;
    icon = "mdi:thermometer";
    name = "[[[ return variables.name ]]]";
    label = ''
      [[[
        if (entity.attributes.current_temperature !== undefined) {
          return entity.attributes.current_temperature + "°C";
        }
        return entity.state;
      ]]]
    '';
    tap_action.action = "more-info";
    styles = mkStyles {
      grid = {
        grid-template-areas = ''"i n window" "i l slider" "i humidity slider"'';
        grid-template-columns = "min-content 1fr min-content";
        grid-template-rows = "min-content min-content min-content";
        column-gap = "10px";
      };
      card = {
        border-radius = "[[[ return variables.radius ]]]";
        background-color = "var(--contrast2)";
        box-shadow = "none";
        padding = "15px";
      };
      icon = {
        width = "40px";
        height = "40px";
        color = "var(--orange)";
      };
      name = {
        justify-self = "start";
        align-self = "end";
        font-size = "14px";
        font-weight = 600;
        color = "var(--contrast20)";
      };
      label = {
        justify-self = "start";
        align-self = "center";
        font-size = "24px";
        font-weight = 700;
        color = "var(--contrast20)";
      };
      custom_fields = {
        window = {
          justify-self = "end";
          align-self = "start";
        };
        humidity = {
          justify-self = "start";
          align-self = "start";
          font-size = "12px";
          color = "var(--contrast14)";
        };
        slider = {
          justify-self = "end";
          align-self = "center";
        };
      };
    };
    custom_fields = {
      window = ''
        [[[
          if (variables.sensor && states[variables.sensor]) {
            if (states[variables.sensor].state == "on") {
              return '<ha-icon icon="mdi:window-open" style="color: var(--blue); width: 20px;"></ha-icon>';
            }
          }
          return "";
        ]]]
      '';
      humidity = ''
        [[[
          if (entity.attributes.current_humidity !== undefined) {
            return '<ha-icon icon="mdi:water-percent" style="width: 14px; color: var(--blue);"></ha-icon> ' + entity.attributes.current_humidity + '%';
          }
          return "";
        ]]]
      '';
      slider.card = {
        type = "custom:button-card";
        styles = mkStyles {
          card = {
            background = "none";
            box-shadow = "none";
            padding = "0";
          };
          grid = {
            grid-template-areas = ''"minus temp plus"'';
            grid-template-columns = "1fr 1fr 1fr";
            column-gap = "5px";
          };
        };
        custom_fields = {
          minus.card = {
            type = "custom:button-card";
            icon = "mdi:minus";
            show_name = false;
            tap_action = {
              action = "call-service";
              service = "climate.set_temperature";
              target.entity_id = "[[[ return entity.entity_id ]]]";
              data.temperature = "[[[ return entity.attributes.temperature - 0.5 ]]]";
            };
            styles = mkStyles {
              card = {
                background = "var(--contrast4)";
                border-radius = "10px";
                padding = "8px";
              };
              icon = {
                width = "16px";
                color = "var(--contrast16)";
              };
            };
          };
          temp = ''
            [[[
              if (entity.attributes.temperature !== undefined) {
                return entity.attributes.temperature + "°";
              }
              return "";
            ]]]
          '';
          plus.card = {
            type = "custom:button-card";
            icon = "mdi:plus";
            show_name = false;
            tap_action = {
              action = "call-service";
              service = "climate.set_temperature";
              target.entity_id = "[[[ return entity.entity_id ]]]";
              data.temperature = "[[[ return entity.attributes.temperature + 0.5 ]]]";
            };
            styles = mkStyles {
              card = {
                background = "var(--contrast4)";
                border-radius = "10px";
                padding = "8px";
              };
              icon = {
                width = "16px";
                color = "var(--contrast16)";
              };
            };
          };
        };
      };
    };
  };

  custom_card_sensor_big = {
    template = "setup";
    show_name = true;
    show_label = false;
    show_icon = true;
    show_state = true;
    tap_action.action = "more-info";
    state_display = ''
      [[[
        var unit = entity.attributes.unit_of_measurement || "";
        return entity.state + '<span style="font-size: 14px; font-weight: 500; color: var(--contrast14);"> ' + unit + '</span>';
      ]]]
    '';
    styles = mkStyles {
      grid = {
        grid-template-areas = ''"i" "n" "s"'';
        grid-template-columns = "1fr";
        grid-template-rows = "1fr min-content min-content";
      };
      card = {
        border-radius = "24px";
        background-color = "var(--contrast2)";
        box-shadow = "none";
        padding = "15px";
        height = "120px";
      };
      icon = {
        width = "32px";
        color = "var(--contrast14)";
        justify-self = "start";
      };
      name = {
        justify-self = "start";
        font-size = "12px";
        font-weight = 500;
        color = "var(--contrast14)";
        margin-top = "auto";
      };
      state = {
        justify-self = "start";
        font-size = "28px";
        font-weight = 700;
        color = "var(--contrast20)";
      };
    };
  };

  custom_card_sensor_medium = {
    template = "setup";
    show_name = true;
    show_label = false;
    show_icon = true;
    show_state = true;
    tap_action.action = "more-info";
    state_display = ''
      [[[
        var unit = entity.attributes.unit_of_measurement || "";
        return entity.state + '<span style="font-size: 12px; font-weight: 500; color: var(--contrast14);"> ' + unit + '</span>';
      ]]]
    '';
    styles = mkStyles {
      grid = {
        grid-template-areas = ''"i n" "s s"'';
        grid-template-columns = "min-content 1fr";
        grid-template-rows = "min-content min-content";
        column-gap = "8px";
      };
      card = {
        border-radius = "24px";
        background-color = "var(--contrast2)";
        box-shadow = "none";
        padding = "12px";
      };
      icon = {
        width = "24px";
        color = "var(--contrast14)";
      };
      name = {
        justify-self = "start";
        align-self = "center";
        font-size = "12px";
        font-weight = 500;
        color = "var(--contrast14)";
      };
      state = {
        justify-self = "start";
        font-size = "20px";
        font-weight = 700;
        color = "var(--contrast20)";
        margin-top = "5px";
      };
    };
  };

  custom_card_sensor_small = {
    template = "setup";
    show_name = true;
    show_label = false;
    show_icon = true;
    show_state = true;
    tap_action.action = "more-info";
    state_display = ''
      [[[
        var unit = entity.attributes.unit_of_measurement || "";
        return entity.state + " " + unit;
      ]]]
    '';
    styles = mkStyles {
      grid = {
        grid-template-areas = ''"i n s"'';
        grid-template-columns = "min-content 1fr min-content";
        grid-template-rows = "min-content";
        column-gap = "8px";
      };
      card = {
        border-radius = "16px";
        background-color = "var(--contrast2)";
        box-shadow = "none";
        padding = "10px 12px";
      };
      icon = {
        width = "20px";
        color = "var(--contrast14)";
      };
      name = {
        justify-self = "start";
        align-self = "center";
        font-size = "12px";
        font-weight = 500;
        color = "var(--contrast14)";
      };
      state = {
        justify-self = "end";
        align-self = "center";
        font-size = "14px";
        font-weight = 600;
        color = "var(--contrast20)";
      };
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
          entity = "[[[ return entity.entity_id ]]]";
          name = template.remainingTime;
          show_icon = false;
          styles = mkStyles {
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
      icon1 = ''[[[ return '<ha-icon icon="mdi:timer-outline"></ha-icon>'; ]]]'';
    };
    styles = mkStyles {
      grid = {
        grid-template-areas = ''"rem icon1" "n icon2" "bar bar"'';
        grid-template-rows = "min-content min-content min-content";
        grid-template-columns = "60% 40%";
      };
      card = {
        padding = "15px 35px 15px 35px";
        background = "var(--contrast2)";
        height = template.stateIfElse {
          entity = mediaPlayers.special.music_and_tv;
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
          entity = entities.inputBooleans.debugRounded;
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
