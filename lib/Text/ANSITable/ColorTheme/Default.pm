package Text::ANSITable::ColorTheme::Default;

use 5.010;
use strict;
use warnings;

use Color::ANSI::Util qw(ansi256fg ansi256bg);
#use Term::ANSIColor;

# VERSION

our %color_themes = (

    no_color => {
        summary => 'Special theme that means no color',
        colors => {
            reset => "",
        },
        no_color => 1,
    },

    default_16 => {
        summary => 'Default for 16-color terminal',
        colors => {
        },
    },

    default_256 => {
        summary => 'Default for 256-color terminal (black background)',
        colors => {
            border      => ansi256fg('ff4499'),
            cell_bg     => '',

            num_data    => '',
            str_data    => '',
            date_data   => '',
            bool_data   => '',
        },
        256 => 1,
    },

);

1;
# ABSTRACT: Default color themes

