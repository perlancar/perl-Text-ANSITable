package Text::ANSITable;

use 5.010001;
use strict;
use warnings;
use Log::Any '$log';
use Moo;

use List::Util 'first';
use Scalar::Util 'looks_like_number';
use Term::ANSIColor;
use Text::ANSI::Util 'ta_mbswidth_height';

# VERSION

has use_color => (
    is      => 'rw',
    default => sub {
        return $ENV{COLOR} if defined $ENV{COLOR};
        if (-t STDOUT) {
            # detect konsole, assume recent enough to support 24bit
            return 2**24 if $ENV{KONSOLE_DBUS_SERVICE}
                || $ENV{KONSOLE_DBUS_SESSION};
            if (($ENV{TERM} // "") =~ /256color/?) {
                return 256;
            }
            return 16;
        } else {
            return 0;
        }
    },
);
has use_box_chars => (
    is      => 'rw',
    default => sub {
        $ENV{BOX_CHARS} // 1;
    },
);
has use_utf8 => (
    is      => 'rw',
    default => sub {
        $ENV{UTF8} //
            (($ENV{LANG} // "") =~ /utf-?8/i ? 1:undef) // 1;
    },
);
has columns => (
    is      => 'rw',
    default => sub { [] },
);
has rows => (
    is      => 'rw',
    default => sub { [] },
);
has display_row_separator => (
    is      => 'rw',
    default => sub { 0 },
);

sub BUILD {
    my ($self, $args) = @_;

    # pick a default border style
    unless ($self->{border_style}) {
        my $bs;
        if ($self->use_utf8) {
            $bs = 'bricko';
        } elsif ($self->use_box_chars) {
            $bs = 'single_boxchar';
        } else {
            $bs = 'single_ascii';
        }
        $self->border_style($bs);
    }

    # pick a default border style
    unless ($self->{color_theme}) {
        my $ct;
        if ($self->use_color) {
            if ($self->use_color >= 256) {
                $ct = 'default_256';
            } else {
                $ct = 'default_16';
            }
        } else {
            $ct = 'no_color';
        }
        $self->color_theme($ct);
    }
}

sub list_border_styles {
    require Module::List;
    require Module::Load;

    my ($self, $detail) = @_;
    state $all_bs;

    if (!$all_bs) {
        my $mods = Module::List::list_modules("Text::ANSITable::BorderStyle::",
                                              {list_modules=>1});
        no strict 'refs';
        $all_bs = {};
        for my $mod (sort keys %$mods) {
            $log->tracef("Loading border style module '%s' ...", $mod);
            Module::Load::load($mod);
            my $bs = \%{"$mod\::border_styles"};
            for (keys %$bs) {
                $bs->{$_}{name} = $_;
                $all_bs->{$_} = $bs->{$_};
            }
        }
    }

    if ($detail) {
        return $all_bs;
    } else {
        return sort keys %$all_bs;
    }
}

sub list_color_themes {
    require Module::List;
    require Module::Load;

    my ($self, $detail) = @_;
    state $all_ct;

    if (!$all_ct) {
        my $mods = Module::List::list_modules("Text::ANSITable::ColorTheme::",
                                              {list_modules=>1});
        no strict 'refs';
        $all_ct = {};
        for my $mod (sort keys %$mods) {
            $log->tracef("Loading color theme module '%s' ...", $mod);
            Module::Load::load($mod);
            my $ct = \%{"$mod\::color_themes"};
            for (keys %$ct) {
                $ct->{$_}{name} = $_;
                $all_ct->{$_} = $ct->{$_};
            }
        }
    }

    if ($detail) {
        return $all_ct;
    } else {
        return sort keys %$all_ct;
    }
}

sub border_style {
    my $self = shift;

    if (!@_) { return $self->{border_style} }
    my $bs = shift;

    if (!ref($bs)) {
        my $all_bs = $self->list_border_styles(1);
        $all_bs->{$bs} or die "Unknown border style name '$bs'";
        $bs = $all_bs->{$bs};
    }

    my $err;
    if ($bs->{box_chars} && !$self->use_box_chars) {
        $err = "use_box_chars is set to false";
    } elsif ($bs->{utf8} && !$self->use_utf8) {
        $err = "use_utf8 is set to false";
    }
    die "Can't select border style: $err" if $err;

    $self->{border_style} = $bs;
}

sub color_theme {
    my $self = shift;

    if (!@_) { return $self->{color_theme} }
    my $ct = shift;

    if (!ref($ct)) {
        my $all_ct = $self->list_color_themes(1);
        $all_ct->{$ct} or die "Unknown color theme name '$ct'";
        $ct = $all_ct->{$ct};
    }

    my $err;
    if (!$ct->{no_color} && !$self->use_color) {
        $err = "use_color is set to false";
    } elsif (!$ct->{no_color} && $ct->{256} &&
                 (!$self->use_color || $self->use_color !~ /256/)) {
        $err = "use_color is not set to 256 color";
    }
    die "Can't select color theme: $err" if $err;

    $self->{color_theme} = $ct;
}

sub add_row {
    my ($self, $row) = @_;
    push @{ $self->{rows} }, $row;
    $self;
}

sub add_rows {
    my ($self, $rows) = @_;
    $self->add_row($_) for @$rows;
    $self;
}

sub cell {
    my $self    = shift;
    my $row_num = shift;
    my $col     = shift;

    unless (looks_like_number($col)) {
        my $n = first { $_ eq $col } @{ $self->{columns} };
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
    for my $c (@{ $self->{columns} }) {
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

    my $bs = $self->{border_style};
    my $ch = $bs->{chars};

    my $bb = $bs->{box_chars} ? "\e(0" : "";
    my $ab = $bs->{box_chars} ? "\e(B" : "";
    my $cols = $self->{columns};

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
        if ($self->{display_row_separator} && $j < @{$self->{rows}}-1) {
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

    #use Data::Dump; dd \@t;
    join "", @t;
}

1;
#ABSTRACT: Create a nice formatted table using extended ASCII and ANSI colors

=for Pod::Coverage ^(BUILD)$

=head1 SYNOPSIS

 use 5.010;
 use Text::ANSITable;

 # don't forget this if you want to output utf8 characters
 binmode(STDOUT, ":utf8");

 my $t = Text::ANSITable->new;

 # set styles
 $t->border_style('bold_utf8');  # if not, it picks a nice default for you
 $t->color_theme('default_256'); # if not, it picks a nice default for you

 # fill data
 $t->columns(["name", "color", "price"]);
 $t->add_row(["chiki"      , "yellow",  2000]);
 $t->add_row(["lays"       , "green" ,  7000]);
 $t->add_row(["tao kae noi", "blue"  , 18500]);
 my $color = $t->cell(2, 1); # => "blue"
 $t->cell(2, 1, "red");

 # draw it!
 say $t->draw;


=head1 DESCRIPTION

This module is yet another text table formatter module like L<Text::ASCIITable>
or L<Text::SimpleTable>, with the following differences:

=over

=item * Colors and color themes

ANSI color codes will be used by default, but will degrade to black and white if
terminal does not support them.

=item * Box-drawing characters

Box-drawing characters will be used by default, but will degrade to using normal
ASCII characters if terminal does not support them.

=item * Unicode support

Columns containing wide characters stay aligned.

=back

Compared to Text::ASCIITable, it uses C<lower_case> method/attr names instead of
C<CamelCase>, and it uses arrayref for C<columns> and C<add_row>. When
specifying border styles, the order of characters are slightly different.

It uses L<Moo> object system.


=head1 ATTRIBUTES

=head2 rows => ARRAY OF ARRAY OF STR

Table contents.

=head2 columns => ARRAY OF STR

Column names.

=head2 use_color => BOOL

Whether to output color. Default is taken from C<COLOR> environment variable, or
detected via C<(-t STDOUT)>. If C<use_color> is set to 0, an attempt to use a
colored color theme (i.e. anything that is not C<no_color>) will result in an
exception.

(In the future, setting C<use_color> to 0 might opt the module to use
normal/plain string routines instead of the slower ta_* functions from
L<Text::ANSI::Util>).

=head2 use_box_chars => BOOL

Whether to use box characters. Default is taken from C<BOX_CHARS> environment
variable, or 1. If C<use_box_chars> is set to 0, an attempt to use a border
style that uses box chararacters will result in an exception.

=head2 use_utf8 => BOOL

Whether to use box characters. Default is taken from C<UTF8> environment
variable, or detected via L<LANG> environment variable, or 1. If C<use_utf8> is
set to 0, an attempt to select a border style that uses Unicode characters will
result in an exception.

(In the future, setting C<use_utf8> to 0 might opt the module to use the
non-"mb_*" version of functions from L<Text::ANSI::Util>, e.g. ta_wrap() instead
of ta_mbwrap(), and so on).

=head2 border_style => HASH

Border style specification to use.

You can set this attribute's value with a specification or border style name.
See L<"/BORDER STYLES"> for more details.

=head2 color_theme => HASH

Color theme specification to use.

You can set this attribute's value with a specification or color theme name. See
L<"/COLOR THEMES"> for more details.

=head2 display_row_separator => BOOL (default 0)

Whether to draw separator between rows.


=head1 METHODS

=head2 $t = Text::ANSITable->new(%attrs) => OBJ

Constructor.

=head2 $t->list_border_styles => LIST

Return the names of available border styles. Border styles will be searched in
C<Text::ANSITable::BorderStyle::*> modules.

=head2 $t->add_row(\@row) => OBJ

Add a row.

=head2 $t->add_rows(\@rows) => OBJ

Add multiple rows.

=head2 $t->cell($row_num, $col[, $val]) => OBJ

Get or set cell value at row #C<$row_num> (starts from zero) and column #C<$col>
(if C<$col> is a number, starts from zero) or column named C<$col> (if C<$col>
does not look like a number).

=head2 $t->draw => STR

Draw the table and return the result.


=head1 BORDER STYLES

To list available border styles:

 say $_ for $t->list_border_styles;

Or you can also run the provided B<ansitable-list-border-styles> script.

Border styles are searched in C<Text::ANSITable::BorderStyle::*> modules
(asciibetically), in the C<%border_styles> variable. Hash keys are border style
names, hash values are border style specifications.

To choose border style, either set the C<border_style> attribute to an available
border style or a border specification directly.

 $t->border_style("singleh_boxchar");
 $t->border_style("foo");   # dies, no such border style
 $t->border_style({ ... }); # set specification directly

If no border style is selected explicitly, a nice default will be chosen. You
can also the C<ANSITABLE_BORDER_STYLE> environment variable to set the default.

To create a new border style, create a module under
C<Text::ANSITable::BorderStyle::>. Please see one of the existing border style
modules for example, like L<Text::ANSITable::BorderStyle::Default>. Format for
the C<chars> specification key:

 [
   [A, b, C, D],
   [E, F, G],
   [H, i, J, K],
   [L, M, N],
   [O, p, Q, R],
   [S, t, U, V],
 ]

 AbbbCbbbD        Top border characters
 E   F   G        Vertical separators for header row
 HiiiJiiiK        Separator between header row and first data row
 L   M   N        Vertical separators for data row
 OpppQpppR        Separator between data rows
 L   M   N
 StttUtttV        Bottom border characters

Each character must have visual width of 1. If A is an empty string, the top
border line will not be drawn. If H is an empty string, the header-data
separator line will not be drawn. If O is an empty string, data separator lines
will not be drawn. If S is an empty string, bottom border line will not be
drawn.


=head1 COLOR THEMES

To list available color themes:

 say $_ for $t->list_color_themes;

Or you can also run the provided B<ansitable-list-color-themes> script.

Color themes are searched in C<Text::ANSITable::ColorTheme::*> modules
(asciibetically), in the C<%color_themes> variable. Hash keys are color theme
names, hash values are color theme specifications.

To choose a color theme, either set the C<color_theme> attribute to an available
color theme or a border specification directly.

 $t->color_theme("default_256");
 $t->color_theme("foo");    # dies, no such color theme
 $t->color_theme({ ... });  # set specification directly

If no color theme is selected explicitly, a nice default will be chosen. You can
also the C<ANSITABLE_COLOR_THEME> environment variable to set the default.

To create a new color theme, create a module under
C<Text::ANSITable::ColorTheme::>. Please see one of the existing color theme
modules for example, like L<Text::ANSITable::ColorTheme::Default>.


=head1 ENVIRONMENT

=head2 COLOR => BOOL

Can be used to set default value for the C<color> attribute.

=head2 BOX_CHARS => BOOL

Can be used to set default value for the C<box_chars> attribute.

=head2 UTF8 => BOOL

Can be used to set default value for the C<utf8> attribute.

=head2 ANSITABLE_BORDER_STYLE => STR

Can be used to set default value for C<border_style> attribute.

=head2 ANSITABLE_COLOR_THEME => STR

Can be used to set default value for C<border_style> attribute.


=head1 FAQ

=head2 I'm getting 'Wide character in print' error message when I use utf8 border styles!

Add something like this first before printing to your output:

 binmode(STDOUT, ":utf8");

=head2 My table looks garbled when viewed through pager like B<less>!

Try using C<-R> option of B<less> to see ANSI color codes. Try not using boxchar
border styles, use the utf8 or ascii version.


=head1 SEE ALSO

L<Text::Table>

L<Text::SimpleTable>

L<Text::ASCIITable>, which I usually used.

L<Text::UnicodeTable::Simple>

L<Table::Simple> (uses Moose)

=cut
