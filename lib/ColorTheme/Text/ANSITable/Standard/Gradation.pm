# no code
## no critic: TestingAndDebugging::RequireUseStrict
package ColorTheme::Text::ANSITable::Standard::Gradation;

# AUTHORITY
# DATE
# DIST
# VERSION

use parent 'ColorThemeBase::Static::FromStructColors';

use Color::RGB::Util qw(mix_2_rgb_colors);

our %THEME = (
    v => 2,
    summary => 'Gradation border (for terminal with black background)',
    args => {
        border1_fg => {
            schema => 'color::rgb24*',
            default => 'ffffff',
        },
        border2_fg => {
            schema => 'color::rgb24*',
            default => '444444',
        },
        border1_bg => {
            schema => 'color::rgb24*',
            default => undef,
        },
        border2_bg => {
            schema => 'color::rgb24*',
            default => undef,
        },
    },
    description => <<'_',

Border color has gradation from top to bottom. Accept arguments `border1_fg` and
`border2_fg` to set first (top) and second (bottom) foreground RGB colors.
Colors will fade from the top color to bottom color. Also accept `border1_bg`
and `border2_bg` to set background RGB colors.

_
    items => {
        border      => sub {
            my ($self, $name, $args) = @_;

            my $t = $args->{table};

            my $pct = ($t->{_draw}{y}+1) / $t->{_draw}{table_height};

            my $rgbf1 = $self->{args}{border1_fg};
            my $rgbf2 = $self->{args}{border2_fg};
            my $rgbf  = mix_2_rgb_colors($rgbf1, $rgbf2, $pct);

            my $rgbb1 = $self->{args}{border1_bg};
            my $rgbb2 = $self->{args}{border2_bg};
            my $rgbb;
            if ($rgbb1 && $rgbb2) {
                $rgbb = mix_2_rgb_colors($rgbb1, $rgbb2, $pct);
            }

            #say "D:$rgbf, $rgbb";
            {fg=>$rgbf, bg=>$rgbb};
        },

        header      => '808080',
        header_bg   => undef,
        cell        => undef,
        cell_bg     => undef,

        num_data    => '66ffff',
        str_data    => undef,
        date_data   => 'aaaa00',
        bool_data   => sub {
            my ($self, $name, $args) = @_;

            $args->{orig_data} ? '00ff00' : 'ff0000';
        },
    },
);

1;
# ABSTRACT:
