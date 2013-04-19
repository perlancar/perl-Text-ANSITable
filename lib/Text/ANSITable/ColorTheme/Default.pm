package Text::ANSITable::ColorTheme::Default;

use 5.010;
use strict;
use warnings;

use Term::ANSIColor;

our %color_themes = (

    no_color => {
        summary => 'Special theme that means no color',
        colors => {
        },
        no_color => 1,
    },

    default_16 => {
        summary => 'Default for 16-color terminal',
        colors => {
        },
    },

    default_256 => {
        summary => 'Default for 256-color terminal',
        colors => {
        },
        256 => 1,
    },

);

1;
# ABSTRACT: Default color themes

