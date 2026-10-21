if hl.plugin.dynamic_cursors then
    hl.config({
        plugin = {
          dynamic_cursors = {
            enabled = true;
            mode = "tilt";
            threshold = 2;

            rotate = {
              length = @cursorSize@;
            };

            shake = {
              enabled = true;
              effects = true;
            };

            hyprcursor = {
              enabled = true;
              nearest = 1;

              resolution = -1;
              fallback = "clientside";
            };
          };
        };
    })
end
