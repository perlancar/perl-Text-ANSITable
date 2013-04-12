package Text::ANSITable;

use 5.010;
use strict;
use warnings;
use overload '""' => 'draw'; # '@{}' => 'addrow_overload',
use Moo;

use List::Util 'first';
use Scalar::Util 'looks_like_number';
use Term::ANSIColor;
use Text::ANSI::Util 'ta_mbswidth_height';

# VERSION

our %border_styles = (

    single_ascii => {
        chars => [
            ['.', '-', '+', '.'],
            ['|', '|', '|'],
            ['+', '-', '+', '|'],
            ['|', '|', '|'],
            ['+', '-', '+', '|'],
            ['`', '-', '+', "'"],
        ],
        before_draw_border => '',
        after_draw_border  => '',
    },

    single_eascii => {
        chars => [
            ['l', 'q', 'w', 'k'],
            ['x', 'x', 'x'],
            ['t', 'q', 'n', 'u'],
            ['x', 'x', 'x'],
            ['t', 'q', 'n', 'u'],
            ['m', 'q', 'v', 'j'],
        ],
        before_draw_border => "\x1b(0",
        after_draw_border  => "\x1b(B",
    },

    singleh_eascii => {
        summary => 'Single horizontal border',
        chars => [
            ['q', 'q', 'q', 'q'],
            [' ', ' ', ' '],
            ['q', 'q', 'q', 'q'],
            [' ', ' ', ' '],
            ['q', 'q', 'q', 'q'],
            ['q', 'q', 'q', 'q'],
        ],
        before_draw_border => "\x1b(0",
        after_draw_border  => "\x1b(B",
    },

    # singlev_eascii => ...

    single_utf8 => {
        summary => 'Single border',
        chars => [
            ["\x{250c}","\x{2500}","\x{252c}","\x{2510}"],
            ["\x{2502}","\x{2502}","\x{2502}"],
            ["\x{251c}","\x{2500}","\x{253c}","\x{2524}"],
            ["\x{2502}","\x{2502}","\x{2502}"],
            ["\x{251c}","\x{2500}","\x{253c}","\x{2524}"],
            ["\x{2514}","\x{2500}","\x{2534}","\x{2518}"],
        ],
        before_draw_border => "",
        after_draw_border  => "",
    },

    csingle_utf8 => {
        summary => 'Curved single border',
        chars => [
            ["\x{256d}","\x{2500}","\x{252c}","\x{256e}"],
            ["\x{2502}","\x{2502}","\x{2502}"],
            ["\x{251c}","\x{2500}","\x{253c}","\x{2524}"],
            ["\x{2502}","\x{2502}","\x{2502}"],
            ["\x{251c}","\x{2500}","\x{253c}","\x{2524}"],
            ["\x{2570}","\x{2500}","\x{2534}","\x{256f}"],
        ],
        before_draw_border => "",
        after_draw_border  => "",
    },

    #bsingle_utf8 => {
    #    summary => 'Bold single border',
    #},

    #vbsingle_utf8 => {
    #    summary => 'Vertically-bold single border',
    #},

    #hbsingle_utf8 => {
    #    summary => 'Horizontally-bold single border',
    #},

    double_utf8 => {
        chars => [
            ["\x{2554}","\x{2550}","\x{2566}","\x{2557}"],
            ["\x{2551}","\x{2551}","\x{2551}"],
            ["\x{2560}","\x{2550}","\x{256c}","\x{2563}"],
            ["\x{2551}","\x{2551}","\x{2551}"],
            ["\x{2560}","\x{2550}","\x{256c}","\x{2563}"],
            ["\x{255a}","\x{2550}","\x{2569}","\x{255d}"],
        ],
        before_draw_border => "",
        after_draw_border  => "",
    },

    hdouble_single_utf8 => {
        summary => 'Horizontally-double border for header, single border for data',
        chars => [
            ["\x{2552}","\x{2550}","\x{2564}","\x{2555}"],
            ["\x{2502}","\x{2502}","\x{2502}"],
            ["\x{255e}","\x{2550}","\x{256a}","\x{2561}"],
            ["\x{2502}","\x{2502}","\x{2502}"],
            ["\x{251c}","\x{2500}","\x{253c}","\x{2524}"],
            ["\x{2514}","\x{2500}","\x{2534}","\x{2518}"],
        ],
        before_draw_border => "",
        after_draw_border  => "",
    },

    single_shadowrb_utf8 => {
        summary => 'Single border, bold on bottom right to give illusion of shadow/depth',
        chars => [
            ["\x{250c}","\x{2500}","\x{252c}","\x{2512}"],
            ["\x{2502}","\x{2502}","\x{2503}"],
            ["\x{251c}","\x{2500}","\x{253c}","\x{2528}"],
            ["\x{2502}","\x{2502}","\x{2503}"],
            ["\x{251c}","\x{2500}","\x{253c}","\x{2528}"],
            ["\x{2515}","\x{2501}","\x{2537}","\x{251b}"],
        ],
        before_draw_border => "",
        after_draw_border  => "",
    },

    singleo_shadowrb_utf8 => {
        summary => 'Single outer border, bold on bottom right to give illusion of shadow/depth',
        chars => [
            ["\x{250c}","\x{2500}","\x{2500}","\x{2512}"],
            ["\x{2502}"," ","\x{2503}"],
            ["\x{2502}"," "," ","\x{2503}"],
            ["\x{2502}"," ","\x{2503}"],
            ["\x{2502}"," "," ","\x{2503}"],
            ["\x{2515}","\x{2501}","\x{2501}","\x{251b}"],
        ],
        before_draw_border => "",
        after_draw_border  => "",
    },

    # singlei_utf8 => {
    #     summary => 'Single inner border',
    # },


);

our %color_themes = (

    default => {
    },

    no_color => {
    },

);

has cols         => (is => 'rw', default => sub { [] });
has rows         => (is => 'rw', default => sub { [] });
has border_style => (
    is => 'rw',
    isa => sub {
        die "Unknown border style '$_[0]'" unless $border_styles{$_[0]};
    },
);
has color_theme  => (
    is => 'rw',
    isa => sub {
        die "Unknown color theme '$_[0]'" unless $color_themes{$_[0]};
    },
);
has draw_row_separator => (is => 'rw', default => sub { 0 });

sub BUILD {
    my ($self, $args) = @_;

    # XXX detect terminal's capability to display extended ascii, fallback to
    # single_ascii
    unless (defined $self->{border_style}) {
        $self->border_style('single_eascii');
    }

    unless (defined $self->{color_theme}) {
        $self->color_theme(defined($ENV{COLOR}) && !$ENV{COLOR} ?
                           'no_color' : 'default');
    }
}

sub add_row {
    my ($self, $row) = @_;
    push @{ $self->{rows} }, $row;
    $self->{rows};
}

sub cell {
    my $self    = shift;
    my $row_num = shift;
    my $col     = shift;

    unless (looks_like_number($col)) {
        my $n = first { $_ eq $col } @{ $self->{cols} };
        die "Unknown column name '$col'" unless defined $n;
        $col = $n;
    }

    if (@_) {
        $self->{rows}[$row_num][$col] = shift;
        return $self;
    } else {
        return $self->{rows}[$row_num][$col];
    }
}

sub draw {
    my ($self) = @_;

    my ($i, $j);

    # determine each column's width
    my @cwidths;
    my @hwidths; # header's widths
    my $hheight = 0;
    $i = 0;
    for my $c (@{ $self->{cols} }) {
        my $wh = ta_mbswidth_height($c);
        my $w = $wh->[0];
        $w = 0 if $w < 0;
        $cwidths[$i] = $hwidths[$i] = $w;
        my $h = $wh->[1];
        $hheight = $h if $hheight < $h;
        $i++;
    }
    $j = 0;
    my @dwidths;  # data row's widths ([row][col])
    my @dheights; # data row's heights
    for my $r (@{ $self->{rows} }) {
        $i = 0;
        for my $c (@$r) {
            next unless defined($c);
            my $wh = ta_mbswidth_height($c);
            my $w = $wh->[0];
            $dwidths[$j][$i] = $w;
            $cwidths[$i] = $w if $cwidths[$i] < $w;
            my $h = $wh->[1];
            if (defined $dheights[$j]) {
                $dheights[$j] = $h if $dheights[$j] > $h;
            } else {
                $dheights[$j] = $h;
            }
            $i++;
        }
        $j++;
    }

    my $bs = $border_styles{$self->{border_style}}
        or die "Unknown border style '$self->{border_style}'";
    my $ch = $bs->{chars};

    my $bb = $bs->{before_draw_border};
    my $ab = $bs->{after_draw_border};
    my $cols = $self->{cols};

    my @t;

    # draw top border
    push @t, $bb, $ch->[0][0];
    $i = 0;
    for my $c (@$cols) {
        push @t, $ch->[0][1] x $cwidths[$i];
        $i++;
        push @t, $i == @$cols ? $ch->[0][3] : $ch->[0][2];
    }
    push @t, $ab, "\n";

    # draw header
    push @t, $bb, $ch->[1][0], $ab;
    $i = 0;
    for my $c (@$cols) {
        push @t, $c, (" " x ($cwidths[$i] - $hwidths[$i]));
        $i++;
        push @t, $bb, ($i == @$cols ? $ch->[1][2] : $ch->[1][1]), $ab;
    }
    push @t, "\n";

    # draw header-data separator
    push @t, $bb, $ch->[2][0];
    $i = 0;
    for my $c (@$cols) {
        push @t, $ch->[2][1] x $cwidths[$i];
        $i++;
        push @t, $i == @$cols ? $ch->[2][3] : $ch->[2][2];
    }
    push @t, $ab, "\n";

    # draw data rows
    $j = 0;
    for my $r0 (@{$self->{rows}}) {
        my @r = @$r0;
        $r[@cwidths-1] = undef if @r < @cwidths; # pad with undefs

        # draw data row
        push @t, $bb, $ch->[3][0], $ab;
        $i = 0;
        for my $c (@r) {
            $c //= ''; $dwidths[$j][$i] //= 0;
            push @t, $c, (" " x ($cwidths[$i] - $dwidths[$j][$i]));
            $i++;
            push @t, $bb, ($i == @$cols ? $ch->[3][2] : $ch->[3][1]), $ab;
        }
        push @t, "\n";

        # draw separator between data rows
        if ($self->{draw_row_separator} && $j < @{$self->{rows}}-1) {
            push @t, $bb, $ch->[4][0];
            $i = 0;
            for my $c (@$cols) {
                push @t, $ch->[4][1] x $cwidths[$i];
                $i++;
                push @t, $i == @$cols ? $ch->[4][3] : $ch->[4][2];
            }
            push @t, $ab, "\n";
        }

        $j++;
    }

    # draw bottom border
    push @t, $bb, $ch->[5][0];
    $i = 0;
    for my $c (@$cols) {
        push @t, $ch->[5][1] x $cwidths[$i];
        $i++;
        push @t, $i == @$cols ? $ch->[5][3] : $ch->[5][2];
    }
    push @t, $ab;

    join "", @t;
}

1;
#ABSTRACT: Create a nice formatted table using extended ASCII and ANSI colors

=head1 SYNOPSIS

 use 5.010;
 use Text::ANSITable;
 my $t = Text::ANSITable->new(
     border_style => 'hdouble_single_utf8',
 );
 $t->cols(["name", "color", "price"]);
 $t->add_row(["chiki"      , "yellow", 2000]);
 $t->add_row(["lays"       , "green" , 5000]);
 $t->add_row(["tao kae noi", "blue"  , 4500]);
 my $color = $t->cell(2, 1); # => "blue"
 $t->cell(2, 1, "red");
 binmode(STDOUT, ":utf8");
 say $t;

will print something like (but with color and extended ASCII characters where
supported by terminal):


=head1 DESCRIPTION

B<NOTE: THIS IS A VERY VERY VERY EARLY VERSION WHERE MOST THINGS ARE NOT EVEN
IMPLEMENTED (BUT THE ABOVE SYNOPSIS WORKS THOUGH)>.

This module is yet another text table formatter module like L<Text::ASCIITable>
or L<Text::SimpleTable>, with the following differences:

=over 4

=item * Colors and color themes

ANSI color codes will be used by default, but will degrade to black and white if
terminal does not support them.

=item * Extended ASCII characters

Extended ASCII (box-drawing) characters will be used by default, but will
degrade to using normal ASCII characters if terminal does not support them.

=item * Unicode

Use UTF-8 by default and handle wide characters so they are kept aligned.

=back

Compared to Text::ASCIITable, it uses C<lower_case> method/attr names instead of
C<CamelCase>, and it uses arrayref for C<cols> and C<add_row>. When specifying
border styles, the order of characters are slightly different.

It uses L<Moo> object system.


=head1 ATTRIBUTES

=head2 rows => ARRAY OF ARRAY OF STR

Table contents.

=head2 cols => ARRAY OF STR

Column names.

=head2 border_style => STR

Name of border style to use when drawing the table. Default is C<single_eascii>,
or C<single_ascii>. For available border styles, see
C<%Text::ANSITable::border_styles>.

=head2 color_theme => STR

Name of color theme to use when drawing the table. Default is C<default>, or
C<no_color>. For available color themes, see C<%Text::ANSITable::color_themes>.

=head2 draw_row_separator => BOOL (default 0)

Whether to draw separator between rows.

=back


=head1 METHODS

=head2 $t = Text::ANSITable->new(%attrs) => OBJ

Constructor.

=head2 $t->add_row(\@row) => OBJ

=head2 $t->cell($row_num, $col[, $val]) => OBJ

Get or set cell value at row #C<$row_num> and column #C<$col> (if C<$col> is a
number) or column named C<$col> (if C<$col> does not look like a number).

=head2 $t->draw => STR

Draw the table and return the result. Or you can just stringify the string:

 "$t"


=head1 FAQ

=head2 I'm getting 'Wide character in print' error message when I use utf8 border styles!

Add something like this first before printing to your output:

 binmode(STDOUT, ":utf8");


=head1 BORDER STYLES

For border styles, here are the characters to supply:

 AbbbCbbbD        Top border characters
 E   F   G        Vertical separators for header row
 HiiiJiiiK        Separator between header row and first data row
 L   M   N        Vertical separators for data row
 OpppQpppR        Separator between data rows
 L   M   N
 StttUtttV        Bottom border characters

Each character must have visual width of 1.

See existing border styles in the source code for examples. Format for C<chars>:

 [
   [A, b, C, D],
   [E, F, G],
   [H, i, J, K],
   [L, M, N],
   [O, p, Q, R],
   [S, t, U, V],
 ]


=head1 SEE ALSO

L<Text::Table>

L<Text::SimpleTable>

L<Text::ASCIITable>, which I usually used.

L<Text::UnicodeTable::Simple>

L<Table::Simple> (uses Moose)

=cut
