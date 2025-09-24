{ lib, ... }:
with (import ../lib.nix { inherit lib; });
{
  footer_template = {
    default = [
      { color-1 = "var(--contrast20)"; }
      { color-2 = "var(--contrast20)"; }
      { color-3 = "var(--contrast20)"; }
      { color-4 = "var(--contrast20)"; }
      { color-5 = "var(--contrast20)"; }
      { bgcolor-1 = "var(--contrast4)"; }
      { bgcolor-2 = "var(--contrast4)"; }
      { bgcolor-3 = "var(--contrast4)"; }
      { bgcolor-4 = "var(--contrast4)"; }
      { bgcolor-5 = "var(--contrast4)"; }
    ];
    card = mkVerticalStack {
      cards = [
        (mkConditional {
          card = card.timer;
          conditions = [
            (condAnd [
              condition.mobileOnly
              condition.timerActive
            ])
          ];
        })
        (mkConditional {
          card = card.mediaPlayer "apple_tv";
          conditions = [
            (condAnd [
              condition.mobileOnly
              condition.tvActive
            ])
          ];
        })
        (mkConditional {
          card = card.alarm;
          conditions = [
            condition.mobileOnly
            condition.alarmActive
            (condUser [
              ids.james
              ids.savannah
            ])
          ];
        })
      ];
    };
  };
}
