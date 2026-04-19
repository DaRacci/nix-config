{ lib, ... }:
let
  viewHeader = import ../components/view-header.nix { };
  navbar = import ../components/navbar.nix { inherit lib; };
  dashLib = import ../lib.nix { inherit lib; };
in
with dashLib;
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
                    item1.card = mkMusicRoomButton {
                      room = "bed_room";
                      icon = "mdi:bed-king-outline";
                      script = "script.play_on_repeat_on_alarm_clock";
                    };
                    item2.card = mkMusicRoomButton {
                      room = "office";
                      icon = "mdi:monitor";
                      script = "script.play_on_repeat_on_office_nest";
                    };
                    item3.card = mkMusicRoomButton {
                      room = "kitchen";
                      icon = "mdi:silverware-variant";
                      script = "script.play_on_repeat_on_kitchen_nest";
                    };
                    item4.card = mkMusicRoomButton {
                      room = "bathroom";
                      icon = "mdi:paper-roll-outline";
                      script = "script.play_on_repeat_on_bathroom_nest";
                    };
                    item5.card = mkMusicRoomButton {
                      room = "spare_room";
                      icon = "mdi:desk";
                      script = "script.play_on_repeat_on_guest_room_nest";
                    };
                    item6.card = mkMusicRoomButton {
                      room = "everywhere";
                      icon = "mdi:home-outline";
                      script = "script.play_on_repeat_on_nest_party";
                    };
                    item7.card = mkMusicRoomButton {
                      room = "living_room";
                      icon = "mdi:sofa-outline";
                      script = "script.play_on_repeat_on_living_room_nest";
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
              entity = mediaPlayers.special.music;
              state_not = "off";
            }
            {
              condition = "state";
              entity = mediaPlayers.special.music;
              state_not = "standby";
            }
            condition.mobileOnly
          ];
          card = {
            type = "vertical-stack";
            cards = [
              {
                square = true;
                columns = 6;
                type = "grid";
                cards = [
                  (mkMusicRoomTransferButton {
                    room = "everywhere";
                    icon = "mdi:home-outline";
                    color = "teal";
                    targetEntity = mediaPlayers.rooms.everywhere;
                    script = "script.play_on_repeat_on_nest_party";
                  })
                  (mkMusicRoomTransferButton {
                    room = "living_room";
                    icon = "mdi:sofa-outline";
                    color = "green";
                    targetEntity = mediaPlayers.rooms.living_room;
                    script = "script.play_on_repeat_on_living_room_nest";
                  })
                  (mkMusicRoomTransferButton {
                    room = "bed_room";
                    icon = "mdi:bed";
                    color = "blue";
                    targetEntity = mediaPlayers.rooms.bedroom_speakers;
                    script = "script.play_on_repeat_on_alarm_clock";
                  })
                  (mkMusicRoomTransferButton {
                    room = "kitchen";
                    icon = "mdi:silverware-variant";
                    color = "yellow";
                    targetEntity = mediaPlayers.rooms.kitchen;
                    script = "script.play_on_repeat_on_kitchen_nest";
                  })
                  (mkMusicRoomTransferButton {
                    room = "bathroom";
                    icon = "mdi:paper-roll-outline";
                    color = "purple";
                    targetEntity = mediaPlayers.rooms.bathroom;
                    script = "script.play_on_repeat_on_bathroom_nest";
                  })
                  (mkMusicRoomTransferButton {
                    room = "spare_room";
                    icon = "mdi:desk";
                    color = "orange";
                    targetEntity = mediaPlayers.rooms.spare_room;
                    script = "script.play_on_repeat_on_guest_room_nest";
                  })
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
                    entity = mediaPlayers.special.music;
                    template = "media_player";
                  }
                  (mkMusicSwipeCard {
                    room = "Living Room";
                    entity = mediaPlayers.rooms.living_room;
                  })
                  (mkMusicSwipeCard {
                    room = "Kitchen";
                    entity = mediaPlayers.rooms.kitchen;
                  })
                  (mkMusicSwipeCard {
                    room = "Bathroom";
                    entity = mediaPlayers.rooms.bathroom;
                  })
                  (mkMusicSwipeCard {
                    room = "Bedroom";
                    entity = mediaPlayers.rooms.bedroom_speakers;
                    conditionEntity = mediaPlayers.rooms.bedroom_nest;
                  })
                  (mkMusicSwipeCard {
                    room = "Spare Room";
                    entity = mediaPlayers.rooms.spare_room;
                  })
                ];
              }
            ];
          };
        }
      ];
    })
  ];
}
