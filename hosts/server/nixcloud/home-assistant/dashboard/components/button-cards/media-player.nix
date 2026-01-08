{ lib, ... }:
with (import ../../lib.nix { inherit lib; });
{
  template = "setup";
  variables = {
    room = "Select Room";
    icon_1 = ''<ha-icon icon="mdi:arrow-up"></ha-icon>'';
    accent_color = "var(--green)";
  };
  show_entity_picture = true;
  show_label = true;
  entity_picture = ''
    [[[
      if (entity.attributes.media_title == undefined || entity.attributes.entity_picture == undefined) {
        return "/local/images/abstract-gif-colors.gif";
      } else {
        return states[entity.entity_id].attributes.entity_picture;
      }
    ]]]
  '';
  name = "[[[ return entity.attributes.media_title ]]]";
  label = "[[[ return entity.attributes.media_artist ]]]";
  tap_action.action = "none";
  styles = {
    grid = {
      grid-template-areas = ''"icon1 select_room play_state icon2" "i i i i" "n n n n" "l l l l" "album album album album" "buttons buttons buttons buttons"'';
      grid-template-columns = "min-content 1fr 1fr min-content";
      # grid-template-rows = "min-content min-content min-content min-content min-content min-content";
    };
    card = {
      background = "none";
      box-shadow = "none";
      border-radius = "0px";
      margin-top = "-10px";
      margin-bottom = "-10px";
      "--mdc-ripple-color" = "black";
      "--mdc-ripple-press-opacity" = 0;
    };
    entity_picture = {
      border-radius = "16px";
      margin-bottom = "35px";
      margin-top = "20px";
      object-fit = "cover";
      width = "200px";
      height = "200px";
    };
    name = {
      justify-self = "center";
      font-weight = 600;
      font-size = "15px";
      padding-top = "10px";
      width = "90%";
    };
    label = {
      justify-self = "center";
      align-self = "start";
      color = "var(--contrast16)";
      font-weight = 500;
      font-size = "12px";
    };
    custom_fields = {
      icon1 = {
        justify-self = "start";
        width = "24px";
        color = "var(--contrast20)";
      };
      icon2 = {
        justify-self = "end";
        width = "24px";
        color = "var(--contrast20)";
      };
      select_room = {
        font-size = "10px";
        justify-self = "start";
        align-self = "center";
        color = "var(--contrast16)";
        padding-left = "10px";
      };
      play_state = {
        font-size = "10px";
        justify-self = "end";
        align-self = "center";
        color = "var(--contrast16)";
        padding-right = "10px";
      };
      album = {
        justify-self = "center";
        align-self = "start";
        color = "var(--contrast16)";
        font-weight = 400;
        font-size = "10px";
        margin-bottom = "5px";
      };
      progress = {
        background-color = "var(--contrast4)";
        position = "absolute";
        top = "unset";
        bottom = "185px";
        left = "20%";
        height = "2px";
        width = "60%";
        border-radius = "4px";
      };
      bar = {
        background-color = "[[[ return variables.accent_color ]]]";
        position = "absolute";
        top = "unset";
        bottom = "185px";
        left = "20%";
        height = "2px";
        z-index = 1;
        border-radius = "4px";
        transition = "1s ease-out";
      };
    };
  };
  customFields = {
    icon1 = "[[[ return variables.icon_1 ]]]";
    icon2 = ''[[[ return '<ha-icon icon="mdi:music"></ha-icon>' ]]]'';
    select_room = "[[[ return variables.room ]]]";
    play_state = jsMatch {
      value = "states[entity.entity_id].attributes.active_child";
      cases = [
        {
          match = "media_player.spotify_james";
          ret = ''states[entity.entity_id].state + " - " + states[entity.entity_id].attributes.source'';
        }
        {
          match = "media_player.apple_tv";
          ret = ''states[entity.entity_id].state + " - " + states[entity.entity_id].attributes.app_name'';
        }
      ];
      default = ''states[entity.entity_id].state + " - " + states[entity.entity_id].attributes.friendly_name'';
    };
    album = mkButtonCard {
      showLabel = true;
      label = "[[[ return states[entity.entity_id].attributes.media_album_name ]]]";
      styles = {
        card = {
          background = "none";
          boxShadow = "none";
          borderRadius = 0;
          padding = 0;
        };
        label = {
          justifySelf = "center";
          alignSelf = "start";
          color = "var(--contrast16)";
          fontWeight = 400;
          fontSize = "10px";
          marginBottom = "5px";
        };
      };
    };
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
                  ? (mediaPosition / mediaDuration * 60)
                  : entity.state === 'playing'
                    ? (((Date.now() / 1000) - (new Date(mediaPositionUpdatedAt).getTime() / 1000) + mediaPosition) / mediaDuration * 60)
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
      styles = {
        card = {
          background = "none";
          box-shadow = "none";
          padding = "0";
        };
        grid = {
          grid-template-areas = ''"loop prev play_pause next shuffle"'';
          grid-template-columns = "1fr 1fr 1fr 1fr 1fr";
          column-gap = "10px";
        };
      };
      custom_fields = {
        loop.card = {
          type = "custom:button-card";
          icon = "mdi:repeat";
          entity = "[[[ return entity.entity_id ]]]";
          show_name = false;
          tap_action = {
            action = "call-service";
            service = "media_player.repeat_set";
            target.entity_id = "[[[ return entity.entity_id ]]]";
            data.repeat = jsMatch {
              value = "entity.attributes.repeat";
              cases = [
                {
                  match = "off";
                  ret = "'all'";
                }
                {
                  match = "all";
                  ret = "'one'";
                }
              ];
              default = "'off'";
            };
          };
          styles = {
            card = {
              background = "var(--contrast4)";
              border-radius = "12px";
              padding = "10px";
            };
            icon = {
              width = "20px";
              color = jsMatch {
                value = "entity.attributes.repeat";
                cases = [
                  {
                    match = "off";
                    ret = "'var(--contrast10)'";
                  }
                ];
                default = "'var(--green)'";
              };
            };
          };
        };
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
          styles = {
            card = {
              background = "var(--contrast4)";
              border-radius = "12px";
              padding = "10px";
            };
            icon = {
              width = "20px";
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
          styles = {
            card = {
              background = "var(--green)";
              border-radius = "12px";
              padding = "10px";
            };
            icon = {
              width = "24px";
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
          styles = {
            card = {
              background = "var(--contrast4)";
              border-radius = "12px";
              padding = "10px";
            };
            icon = {
              width = "20px";
              color = "var(--contrast16)";
            };
          };
        };
        shuffle.card = {
          type = "custom:button-card";
          icon = "mdi:shuffle";
          entity = "[[[ return entity.entity_id ]]]";
          show_name = false;
          tap_action = {
            action = "call-service";
            service = "media_player.shuffle_set";
            target.entity_id = "[[[ return entity.entity_id ]]]";
            data.shuffle = "[[[ return !entity.attributes.shuffle ]]]";
          };
          styles = {
            card = {
              background = "var(--contrast4)";
              border-radius = "12px";
              padding = "10px";
            };
            icon = {
              width = "20px";
              color = ''
                [[[
                  if (entity.attributes.shuffle) return "var(--green)";
                  else return "var(--contrast10)";
                ]]]
              '';
            };
          };
        };
      };
    };
  };
}
