{ lib }:
let
  viewHeader = import ../components/view-header.nix { };
  navbar = import ../components/navbar.nix { inherit lib; };
  adminPanel = import ../components/admin-panel.nix { inherit lib; };
in
with (import ../lib.nix { inherit lib; });
mkView {
  title = "Home";
  header = viewHeader;
  path = "home";
  icon = "mdi:home-assistant";

  badges = standardBadges;

  sections = [
    (mkGridSection {
      cards = [
        navbar
        adminPanel
      ];
      grid_options = {
        columns = "full";
        rows = "auto";
      };
    })

    # (mkGridSection)

    # Popups
    (mkGridSection {
      cards = [
        (mkVerticalStack {
          cards = [
            (mkBubbleCard {
              name = "Bedroom";
              icon = "mdi:bed-king-outline";
              cardType = "pop-up";
              hash = "#bedroom";
            })

            (mkMushroomChipsCard {
              chips = [
                (mkEntity {
                  entity = "binary_sensor.bedroom_presence_sensor";
                  contentInfo = "last-changed";
                  icon = "mdi:motion-sensor";
                  iconColor = "yellow";
                })
                (mkEntity {
                  entity = "binary_sensor.bedroom_window_sensor";
                  icon = "mdi:window-closed-variant";
                  iconColor = "red";
                })
                (mkEntity {
                  entity = "binary_sensor.bedroom_door_sensor";
                  icon = "mdi:door-closed";
                  iconColor = "blue";
                })
              ];
            })

            (mkHeading {
              heading = "Climate";
              heading_style = "title";
              icon = "mdi:thermostat";
              badges = [
                (mkEntity {
                  entity = "climate.bedroom_ac";
                  stateContent = "current_temperature";
                  color = "red";
                  showIcon = true;
                  showState = true;
                  tapAction = mkAction { action = "toggle"; };
                })
                (mkEntity {
                  entity = "climate.bedroom_ac";
                  stateContent = "current_humidity";
                  color = "blue";
                  showIcon = true;
                  showState = true;
                  tapAction = mkAction { action = "toggle"; };
                })
              ];
            })
            (mkBubbleCard {
              cardType = "climate";
              entity = "climate.bedroom_ac";
              showState = true;
              subButton = [
                {
                  name = "HVAC modes menu";
                  select_attribute = "hvac_modes";
                  state_background = false;
                  show_arrow = false;
                }
              ];
            })

            (mkHeading {
              heading = "Devices";
              heading_style = "title";
              icon = "mdi:devices";
              badges = [
                (mkEntity {
                  entity = "input_boolean.bedroom_occupancy";
                  icon = "mdi:light-switch";
                  color = "red";
                  showState = false;
                  showIcon = true;
                  tapAction = mkAction { action = "toggle"; };
                })
                (mkEntity {
                  entity = "input_boolean.bedroom_night_mode";
                  showState = false;
                  showIcon = true;
                  color = "blue";
                  tapAction = mkAction { action = "toggle"; };
                })
              ];
            })

            (mkGridSection {
              columns = 3;
              cards = [
                (mkButtonCard {
                  entity = "binary_sensor.is_alarm_on";
                  name = "Alarm";
                  label = template.getState "sensor.wake_time_1";
                  template = "nav_button_small";
                  variables = {
                    navigationPath = "home#alarm";
                    iconOn = "mdi:alarm";
                    iconOff = "mdi:alarm-off";
                    backgroundColorOn = jsColours.yellow;
                    backgroundColorOff = jsColours.contrast2;
                    colorOn = jsColours.black;
                    colorOff = jsColours.contrast20;
                  };
                })
                (mkConditional {
                  conditions = [
                    (condState {
                      entity = "alarm_control_panel.security_system";
                      state = "armed_night";
                    })
                  ];
                  card = mkButtonCard {
                    entity = "input_boolean.waking_up";
                    name = "Waking Up";
                    label = template.getState "input_boolean.waking_up";
                    showLabel = true;
                    tapAction = mkAction {
                      action = "toggle";
                      haptic = "success";
                    };
                    template = "button_template";
                    variables = {
                      icon2 = "mdi:weather-sunset-up";
                      backgroundColorOff = jsColours.contrast2;
                      backgroundColorOn = jsColours.orange;
                      colorOn = jsColours.black;
                      colorOff = jsColours.contrast20;
                    };
                  };
                })
                (mkConditional {
                  conditions = [
                    (condState {
                      entity = "alarm_control_panel.security_system";
                      state = "armed_night";
                    })
                  ];
                  card = mkButtonCard {
                    entity = "input_boolean.going_to_bed";
                    name = "Waking Up";
                    label = template.getState "input_boolean.going_to_bed";
                    showLabel = true;
                    tapAction = mkAction {
                      action = "toggle";
                      haptic = "success";
                    };
                    template = "button_template";
                    variables = {
                      icon2 = "mdi:bed";
                      backgroundColorOff = jsColours.contrast2;
                      backgroundColorOn = jsColours.blue;
                      colorOn = jsColours.black;
                      colorOff = jsColours.contrast20;
                    };
                  };
                })
              ];
            })

            (mkGridSection {
              columns = 1;
              cards = [
                (mkHeading {
                  heading = "Lights";
                  heading_style = "subtitle";
                  icon = "mdi:lightbulb-group";
                  badges = [
                    (mkEntity {
                      entity = "light.bedroom_lights";
                      showIcon = true;
                      showState = false;
                      color = "yellow";
                      tapAction = mkAction { action = "toggle"; };
                    })
                    (mkEntity {
                      entity = "switch.adaptive_lighting_bedroom";
                      showIcon = true;
                      showState = false;
                      color = "orange";
                      tapAction = mkAction { action = "toggle"; };
                    })
                    (mkEntity {
                      entity = "switch.adaptive_lighting_adapt_color_bedroom";
                      showIcon = true;
                      showState = false;
                      color = "pink";
                      tapAction = mkAction { action = "toggle"; };
                    })
                    (mkEntity {
                      entity = "switch.adaptive_lighting_adapt_brightness_bedroom";
                      showIcon = true;
                      showState = false;
                      color = "yellow";
                      tapAction = mkAction { action = "toggle"; };
                    })
                    (mkEntity {
                      entity = "switch.adaptive_lighting_sleep_mode_bedroom";
                      showIcon = true;
                      showState = false;
                      color = "blue";
                      tapAction = mkAction { action = "toggle"; };
                    })
                  ];
                })

                (mkGridSection {
                  columns = 1;
                  cards = [
                    (mkButtonCard {
                      name = "Top Light";
                      entity = "lighting.bedroom_light";
                      template = "light_rgb";
                    })
                  ];
                })
              ];
            })

            (mkHeading {
              heading = "Media";
              heading_style = "title";
              icon = "mdi:music";
            })
            (mkSwipeCard {
              cardWidth = "calc(100% - 48px)";
              parameters = {
                centeredSlides = true;
                slidesPerView = "auto";
                spaceBetween = 16;
                initialSlide = 0;
              };
              cards = [
                (mkConditional {
                  conditions = [
                    (condState {
                      entity = "media_player.bedroom_speakers";
                      state_not = "standby";
                    })
                    (condState {
                      entity = "media_player.bedroom_speakers";
                      state_not = "off";
                    })
                  ];
                  card = mkButtonCard {
                    entity = "media_player.bedroom_speakers";
                    template = "custom_card_mediaplayer_music";
                  };
                })

                (mkConditional {
                  conditions = [
                    (condState {
                      entity = "sensor.bedroom_next_timer";
                      state_not = "unknown";
                    })
                    (condState {
                      entity = "sensor.bedroom_next_timer";
                      state_not = "unavailable";
                    })
                  ];
                  card = mkButtonCard {
                    entity = "sensor.bedroom_next_timer";
                    name = "Bedroom Timer";
                    icon = "mdi:timer-outline";
                    showName = true;
                    showIcon = true;
                    showLabel = false;
                    showState = false;
                    tapAction = mkAction {
                      action = "more-info";
                    };
                    holdAction = mkAction {
                      action = "navigate";
                    };
                    customFields = {
                      bar = ''
                        [[[
                          var color = "var(--green)";
                          var state = 100 - states['sensor.bed_room_timer'].attributes.remaining_perc;
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
                      rem.card = mkConditional {
                        conditions = [
                          (condState {
                            entity = "sensor.bedroom_next_timer";
                            state_not = "unknown";
                          })
                        ];
                        card = mkButtonCard {
                          entity = "sensor.bedroom_next_timer";
                          name = template.remainingTime;
                          showIcon = false;
                          styles = mkStyles {
                            card = {
                              width = "min";
                              background = "none";
                              overflow = "visible";
                            };
                            name = {
                              font-size = "14px";
                              margin-top = "6px";
                              font-weight = 600;
                              color = jsColours.contrast20;
                            };
                          };
                        };
                      };
                      icon1 = template.returnIcon "mdi:bed-king-outline";
                    };
                    styles = mkStyles {
                      grid = {
                        grid-template-areas = "\"rem icon1\" \"n icon2\" \"bar bar\"";
                        grid-template-rows = "24px 1fr 24px min-content min-content min-content";
                        grid-template-columns = "60% 40%";
                      };
                      card = {
                        height = "100%";
                        padding = "1rem";
                        background = jsColours.contrast2;
                      };
                      img_cell = {
                        position = "absolute";
                        top = "20%";
                        left = "40%";
                        overflow = "visible";
                      };
                      icon = {
                        position = "absolute";
                        width = "20em";
                        opacity = "20%";
                        color = jsColours.contrast20;
                        transform = "rotate(-20deg)";
                      };
                      label = {
                        text-align = "left";
                        font-size = "18px";
                        font-weight = 500;
                        justify-self = "start";
                        align-self = "end";
                        overflow = "visible";
                        color = jsColours.contrast20;
                      };
                      name = {
                        text-align = "left";
                        font-size = "12px";
                        justify-self = "start";
                        align-self = "center";
                        overflow = "visible";
                        color = jsColours.contrast20;
                      };
                      custom_fields = {
                        bar = {
                          justify-self = "start";
                          width = "100%";
                          height = template.stateIfElse {
                            entity = "entity.state";
                            states = [ "unknown" ];
                            ifTrue = "0px";
                            ifFalse = "12px";
                          };
                        };
                        rem = {
                          justify-self = "start";
                          font-size = "14px";
                          font-weight = 600;
                          align-self = "end";
                          height = template.stateIfElse {
                            entity = "entity.state";
                            states = [ "unknown" ];
                            ifTrue = "0px";
                            ifFalse = "27px";
                          };
                        };
                      };
                      icon1 = {
                        justify-self = "end";
                        width = "24px";
                        color = jsColours.contrast20;
                      };
                    };
                  };
                })
              ];
            })
          ];
        })
      ];
      grid_options = {
        column_span = 3;
      };
    })
  ];
}
