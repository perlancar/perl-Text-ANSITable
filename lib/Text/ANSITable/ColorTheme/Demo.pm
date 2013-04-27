package Text::ANSITable::ColorTheme::Demo;

use 5.010;
use strict;
use warnings;

use Color::ANSI::Util qw(ansi256fg ansi24bfg);
use SHARYANTO::Color::Util qw(mix_2_rgb_colors);

# VERSION

our %color_themes = (

    demo_random_border_color => {
        summary => 'Demoes coderef in item color',
        colors => {
            border => sub {
                my ($self, %args) = @_;
                my $rgb = sprintf("%02x%02x%02x",
                                  rand()*256, rand()*256, rand()*256);
                ansi256fg($rgb);
            },
        },
        256 => 1,
    },

    demo_gradation_border_color => {
        summary => 'Demoes coderef in item color',
        description => <<'_',

Accept arguments 'border1' and 'border2' to set first and second RGB colors.

_
        colors => {
            border => sub {
                my ($self, %args) = @_;

                my $rgb1 = $self->{color_theme_args}{border1} // 'ffffff';
                my $rgb2 = $self->{color_theme_args}{border2} // '444444';

                my $y;
                my $num_rows = @{$self->{_draw}{frows}};
                my $bcy = $args{bch}[0];
                if ($bcy == 0) {
                    $y = 0;
                } elsif ($bcy == 1) {
                    $y = 1;
                } elsif ($bcy == 2) {
                    $y = 2;
                } elsif ($bcy == 5) {
                    $y = $num_rows + 3;
                } else {
                    $y = $args{row_idx}+3;
                }

                my $rgb = mix_2_rgb_colors($rgb1, $rgb2, $y/($num_rows+3));
                my $res = ansi24bfg($rgb);
                #say "D:$rgb";
                $res;
            },
        },
        '24bit' => 1,
    },

);

1;
# ABSTRACT: Demo color themes

