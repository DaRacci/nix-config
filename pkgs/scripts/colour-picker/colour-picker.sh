#!/usr/bin/env bash

# TODO: Allow zooming in and out with mouse wheel
sensitivity_before=$(hyprctl getoption input.sensitivity -j | gojq -r '.float')
hyprctl eval 'hl.config({ ["input.sensitivity"] = -0.8 })'
hyprpicker --render-inactive --autocopy
hyprctl eval "hl.config({ [\"input.sensitivity\"] = $sensitivity_before })"
