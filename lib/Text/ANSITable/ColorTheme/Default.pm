package Text::ANSITable::ColorTheme::Default;

use 5.010;
use strict;
use warnings;

use Data::Clone;
use SHARYANTO::Color::Util qw(mix_2_rgb_colors);

# VERSION

our %color_themes = (

    no_color => {
        summary => 'Special theme that means no color',
        colors => {
        },
        no_color => 1,
    },

    #default_16 => {
    #    summary => 'Default for 16-color terminal',
    #    colors => {
    #    },
    #},

    #default_256 => {
    default_gradation => {
        summary => 'Default (for terminal with black background)',
        description => <<'_',

Border color has gradation from top to bottom. Accept arguments C<border1> and
C<border2> to set first (top) and second (bottom) foreground RGB colors. Colors
will fade from the top color to bottom color. Also accept C<border1_bg> and
C<border2_bg> to set background RGB colors.

_
        colors => {
            border      => sub {
                my ($self, %args) = @_;

                my $pct = ($self->{_draw}{y}+1) / $self->{_draw}{table_height};

                my $rgbf1 = $self->{color_theme_args}{border1} // $self->{color_theme}{data}{default_border1} // 'ffffff';
                my $rgbf2 = $self->{color_theme_args}{border2} // $self->{color_theme}{data}{default_border2} // '444444';
                my $rgbf  = mix_2_rgb_colors($rgbf1, $rgbf2, $pct);

                my $rgbb1 = $self->{color_theme_args}{border1_bg};
                my $rgbb2 = $self->{color_theme_args}{border2_bg};
                my $rgbb;
                if ($rgbb1 && $rgbb2) {
                    $rgbb = mix_2_rgb_colors($rgbb1, $rgbb2, $pct);
                }

                #say "D:$rgbf, $rgbb";
                [$rgbf, $rgbb];
            },

            header      => '808080', # "\e[1m" or "\e[1;7m" currently doesn't work, why?
            header_bg   => undef,
            cell        => undef,
            cell_bg     => undef,

            num_data    => '66ffff',
            str_data    => undef,
            date_data   => 'aaaa00',
            bool_data   => sub {
                my ($self, %args) = @_;

                $args{orig_data} ? '00ff00' : 'ff0000';
            },
        },
    },

);

my $ng = clone($color_themes{default_gradation});
$ng->{colors}{border} = '666666';
delete $ng->{description};
$color_themes{default_nogradation} = $ng;

my $dgw = clone($color_themes{default_gradation});
$dgw->{summary} = 'Default (for terminal with white background)';
$dgw->{colors}{header_bg} = 'cccccc';
$dgw->{data}{default_border1} = '000000';
$dgw->{data}{default_border2} = 'cccccc';
$dgw->{colors}{num_data}  = '006666',
$dgw->{colors}{date_data} = '666600';
$dgw->{colors}{bool_data} = sub {
    my ($self, %args) = @_;

    $args{orig_data} ? '00cc00' : 'cc0000';
},
$color_themes{default_gradation_whitebg} = $dgw;

1;
# ABSTRACT: Default color themes

