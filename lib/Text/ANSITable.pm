package Text::ANSITable;

use 5.010001;
use strict;
use warnings;
use Log::Any '$log';
use Moo;

#use List::Util 'first';
use Scalar::Util 'looks_like_number';
use Text::ANSI::Util qw(ta_mbswidth_height ta_mbpad);

# VERSION

has use_color => (
    is      => 'rw',
    default => sub {
        return $ENV{COLOR} if defined $ENV{COLOR};
        if (-t STDOUT) {
            # detect konsole, assume recent enough to support 24bit
            return 2**24 if $ENV{KONSOLE_DBUS_SERVICE}
                || $ENV{KONSOLE_DBUS_SESSION};
            if (($ENV{TERM} // "") =~ /256color/) {
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
has column_filter => (
    is => 'rw',
);
has row_filter => (
    is => 'rw',
);
has _row_separators => ( # [index after which sep should be drawn, ...] sorted
    is      => 'rw',
    default => sub { [] },
);
has show_row_separator => (
    is      => 'rw',
    default => sub { 0 },
);
has show_header => (
    is      => 'rw',
    default => sub { 1 },
);
has _column_styles => ( # store per-column styles
    is      => 'rw',
    default => sub { [] },
);
has _row_styles => ( # store per-row styles
    is      => 'rw',
    default => sub { [] },
);
has _cell_styles => ( # store per-cell styles
    is      => 'rw',
    default => sub { [] },
);
has column_pad => (
    is      => 'rw',
    default => sub { 1 },
);
has column_lpad => (
    is      => 'rw',
);
has column_rlpad => (
    is      => 'rw',
);
has row_vpad => (
    is      => 'rw',
    default => sub { 0 },
);
has row_tpad => (
    is      => 'rw',
);
has row_bpad => (
    is      => 'rw',
);
has cell_fgcolor => (
    is => 'rw',
);
has cell_bgcolor => (
    is => 'rw',
);
has column_align => (
    is => 'rw',
);
has row_valign => (
    is => 'rw',
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
                 (!$self->use_color || $self->use_color < 256)) {
        $err = "use_color is not set to 256 color";
    }
    die "Can't select color theme: $err" if $err;

    $self->{color_theme} = $ct;
}

sub add_row {
    my ($self, $row, $styles) = @_;
    die "Row must be arrayref" unless ref($row) eq 'ARRAY';
    push @{ $self->{rows} }, $row;
    if ($styles) {
        my $i = @{ $self->{rows} }-1;
        for my $s (keys %$styles) {
            $self->row_style($i, $s, $styles->{$s});
        }
    }
    $self;
}

sub add_row_separator {
    my ($self) = @_;
    my $idx = ~~@{$self->{rows}}-1;
    # ignore duplicate separators
    push @{ $self->{_row_separators} }, $idx
        unless @{ $self->{_row_separators} } &&
            $self->{_row_separators}[-1] == $idx;
    $self;
}

sub add_rows {
    my ($self, $rows, $styles) = @_;
    die "Rows must be arrayref" unless ref($rows) eq 'ARRAY';
    $self->add_row($_, $styles) for @$rows;
    $self;
}

sub _colidx {
    my $self = shift;
    my $colname = shift;

    return $colname if looks_like_number($colname);
    my $cols = $self->{columns};
    for my $i (0..@$cols-1) {
        return $i if $cols->[$i] eq $colname;
    }
    die "Unknown column name '$colname'";
}

sub cell {
    my $self    = shift;
    my $row_num = shift;
    my $col     = shift;

    $col = $self->_colidx($col);

    if (@_) {
        my $oldval = $self->{rows}[$row_num][$col];
        $self->{rows}[$row_num][$col] = shift;
        return $oldval;
    } else {
        return $self->{rows}[$row_num][$col];
    }
}

sub column_style {
    my $self  = shift;
    my $col   = shift;
    my $style = shift;

    $col = $self->_colidx($col);

    if (@_) {
        my $oldval = $self->{_column_styles}[$col]{$style};
        $self->{_column_styles}[$col]{$style} = shift;
        return $oldval;
    } else {
        return $self->{_column_styles}[$col]{$style};
    }
}

sub row_style {
    my $self  = shift;
    my $row   = shift;
    my $style = shift;

    if (@_) {
        my $oldval = $self->{_row_styles}[$row]{$style};
        $self->{_row_styles}[$row]{$style} = shift;
        return $oldval;
    } else {
        return $self->{_row_styles}[$row]{$style};
    }
}

sub cell_style {
    my $self  = shift;
    my $row   = shift;
    my $col   = shift;
    my $style = shift;

    $col = $self->_colidx($col);

    if (@_) {
        my $oldval = $self->{_cell_styles}[$row][$col]{$style};
        $self->{_cell_styles}[$row][$col]{$style} = shift;
        return $oldval;
    } else {
        return $self->{_cell_styles}[$row][$col]{$style};
    }
}

# filter columns & rows, calculate widths/paddings, format data, put the results
# in _dd (draw data) attribute.
sub _prepare_draw {
    my $self = shift;

    $self->{_dd} = {};
    my $cf    = $self->{column_filter};
    my $rf    = $self->{row_filter};
    my $cols  = $self->{columns};
    my $rows  = $self->{rows};

    # determine which columns to show
    my $fcols;
    if (ref($cf) eq 'CODE') {
        $fcols = [grep {$cf->($_)} @$cols];
    } elsif (ref($cf) eq 'ARRAY') {
        $fcols = $cf;
    } else {
        $fcols = $cols;
    }

    # calculate widths/heights of header
    my $fcol_widths = []; # index = [colnum]
    my $header_height;
    {
        my %seen;
        for my $i (0..@$cols-1) {
            next unless $cols->[$i] ~~ $fcols;
            next if $seen{$cols->[$i]}++;
            my $wh = ta_mbswidth_height($cols->[$i]);
            $fcol_widths->[$i] = $wh->[0];
            $header_height = $wh->[1]
                if !defined($header_height) || $header_height < $wh->[1];
        }
    }
    $self->{_dd}{header_height} = $header_height;

    # calculate vertical paddings of data rows
    my $frow_tpads  = []; # index = [frowidx]
    my $frow_bpads  = []; # ditto
    my $frows = [];
    my $frow_separators = [];
    my $frow_orig_index = []; # needed when accessing original row data
    {
        my $tpad = $self->{row_tpad} // $self->{row_vpad}; # tbl-lvl top padding
        my $bpad = $self->{row_bpad} // $self->{row_vpad}; # tbl-lvl botom pad
        my $i = -1;
        my $j = -1;
        for my $row (@$rows) {
            $i++;
            if (ref($rf) eq 'CODE') {
                next unless $rf->($row, $i);
            } elsif ($rf) {
                next unless $i ~~ $rf;
            }
            $j++;
            push @$frows, [@$row]; # 1-level clone, for storing formatted values
            push @$frow_separators, $j if $i ~~ $self->{_row_separators};
            push @$frow_tpads, $self->row_style($i, 'tpad') //
                $self->row_style($i, 'vpad') // $tpad;
            push @$frow_bpads, $self->row_style($i, 'bpad') //
                $self->row_style($i, 'vpad') // $bpad;
            push @$frow_orig_index, $i;
        }
    }
    $self->{_dd}{fcols}      = $fcols;
    $self->{_dd}{frow_tpads} = $frow_tpads;
    $self->{_dd}{frow_bpads} = $frow_bpads;

    # apply column formats, calculate pads of columns
    my $fcol_lpads  = []; # index = [colnum]
    my $fcol_rpads  = []; # ditto
    {
        my $lpad = $self->{column_lpad} // $self->{column_pad}; # tbl-lvl leftp
        my $rpad = $self->{column_rpad} // $self->{column_pad}; # tbl-lvl rightp
        my %seen;
        for my $i (0..@$cols-1) {
            next unless $cols->[$i] ~~ $fcols;
            next if $seen{$cols->[$i]}++;
            my $fmts = $self->column_style($i, 'formats');
            if (defined $fmts) {
                require Data::Unixish::Apply;
                my $res = Data::Unixish::Apply::apply(
                    in => [map {$frows->[$_][$i]} 0..@$frows-1],
                    functions => $fmts,
                );
                die "Can't format column $cols->[$i]: $res->[0] - $res->[1]"
                    unless $res->[0] == 200;
                $res = $res->[2];
                for (0..@$frows-1) { $frows->[$_][$i] = $res->[$_] }
            }
            $fcol_lpads->[$i] = $self->column_style($i, 'lpad') //
                $self->column_style($i, 'pad') // $lpad;
            $fcol_rpads->[$i] = $self->column_style($i, 'rpad') //
                $self->column_style($i, 'pad') // $rpad;
        }
    }
    $self->{_dd}{fcol_lpads}  = $fcol_lpads;
    $self->{_dd}{fcol_rpads}  = $fcol_rpads;

    # apply cell formats, calculate widths/heights of data rows
    my $frow_heights = []; # index = [frowidx]
    {
        my $cswidths = [map {$self->column_style($_, 'width')} 0..@$cols-1];
        my $val;
        for my $i (0..@$frows-1) {
            my %seen;
            for my $j (0..@$cols-1) {
                next unless $cols->[$j] ~~ $fcols;
                next if $seen{$cols->[$j]}++;

                # apply cell-level formats
                my $fmts = $self->cell_style($i, $j, 'formats');
                if (defined $fmts) {
                    require Data::Unixish::Apply;
                    my $origi = $frow_orig_index->[$j];
                    my $res = Data::Unixish::Apply::apply(
                        in => [ $rows->[$origi][$j] ],
                        functions => $fmts,
                    );
                    die "Can't format cell ($origi, $cols->[$j]): ".
                        "$res->[0] - $res->[1]" unless $res->[0] == 200;
                    $frows->[$i][$j] = $res->[2][0];
                }

                # calculate heights/widths of data
                my $wh = ta_mbswidth_height($frows->[$i][$j] // "");
                $frow_heights->[$i] = $wh->[1]
                    if !defined($frow_heights->[$i]) ||
                        $frow_heights->[$i] < $wh->[1];
                $val = $wh->[0];
                if (defined $cswidths->[$j]) {
                    if ($cswidths->[$j] < 0) {
                        # widen to minimum width
                        $val = -$cswidths->[$j] if $val < -$cswidths->[$j];
                    } else {
                        $val =  $cswidths->[$j] if $val <  $cswidths->[$j];
                    }
                }
                $fcol_widths->[$j] = $val if $fcol_widths->[$j] < $val;
            }
        }
    }
    $self->{_dd}{frow_heights} = $frow_heights;
    $self->{_dd}{fcol_widths}  = $fcol_widths;
    $self->{_dd}{frows}        = $frows;
}

sub draw {
    my ($self) = @_;

    $self->_prepare_draw;

    my $cols  = $self->{cols};
    my $fcols = $self->{_dd}{fcols};
    my $frows = $self->{_dd}{frows};
    my $fcol_lpads  = $self->{_dd}{fcol_lpads};
    my $fcol_rpads  = $self->{_dd}{fcol_rpads};
    my $frow_tpads  = $self->{_dd}{frow_tpads};
    my $frow_bpads  = $self->{_dd}{frow_bpads};
    my $fcol_widths = $self->{_dd}{fcol_widths};

    my $bs  = $self->{border_style};
    my $bch = $bs->{chars};

    my $bb = $bs->{box_chars} ? "\e(0" : "";
    my $ab = $bs->{box_chars} ? "\e(B" : "";

    my $colors = $self->{color_theme}{colors};

    my @s; # the result string

    my $draw_bch = sub {
        push @s, $colors->{border} // "", $bb;
        while (my ($y, $x, $n) = splice @_, 0, 3) {
            push @s, $bch->[$y][$x] x ($n // 1);
        }
        push @s, $ab, $colors->{reset};
    };

    # draw border top line
    {
        last unless length($bch->[0][0]);
        my @b;
        push @b, 0, 0, 1;
        for my $i (0..@$fcols-1) {
            my $ci = $self->_colidx($fcols->[$i]);
            push @b, 0, 1,
                $fcol_lpads->[$ci] + $fcol_widths->[$ci] + $fcol_rpads->[$ci];
            push @b, 0, $i==@$fcols-1 ? 3:2, 1;
        }
        $draw_bch->(@b);
        push @s, "\n";
    }

    # draw header
    if ($self->{show_header}) {
        $draw_bch->(1, 0);

        for my $i (0..@$fcols-1) {
            my $ci = $self->_colidx($fcols->[$i]);
            push @s, " " x $fcol_lpads->[$ci];
            my $cell = ta_mbpad(
                $fcols->[$i], $fcol_widths->[$ci], "r", " ", 1);
            # XXX give cell fgcolor/bgcolor ...
            push @s, $cell;
            push @s, " " x $fcol_rpads->[$ci];

            $draw_bch->(1, $i == @$fcols-1 ? 2:1);
        }
        push @s, "\n";
    }

    # draw header-data row separator
    if ($self->{show_header} && length($bch->[2][0])) {
        my @b;
        push @b, 2, 0, 1;
        for my $i (0..@$fcols-1) {
            my $ci = $self->_colidx($fcols->[$i]);
            push @b, 2, 1,
                $fcol_lpads->[$ci] + $fcol_widths->[$ci] + $fcol_rpads->[$ci];
            push @b, 2, $i==@$fcols-1 ? 3:2, 1;
        }
        $draw_bch->(@b);
        push @s, "\n";
    }

    # draw data rows
    {
        for my $r (0..@$frows-1) {
            $draw_bch->(3, 0);
            for my $i (0..@$fcols-1) {
                my $ci = $self->_colidx($fcols->[$i]);
                push @s, " " x $fcol_lpads->[$ci];
                my $cell = ta_mbpad(
                    $frows->[$r][$i], $fcol_widths->[$ci], "r", " ", 1);
                # XXX give cell fgcolor/bgcolor ...
                push @s, $cell;
                push @s, " " x $fcol_rpads->[$ci];

                $draw_bch->(3, $i == @$fcols-1 ? 2:1);
            }
            push @s, "\n";
        }
    }

    # XXX draw row separator

    # draw border bottom line
    {
        last unless length($bch->[5][0]);
        my @b;
        push @b, 5, 0, 1;
        for my $i (0..@$fcols-1) {
            my $ci = $self->_colidx($fcols->[$i]);
            push @b, 5, 1,
                $fcol_lpads->[$ci] + $fcol_widths->[$ci] + $fcol_rpads->[$ci];
            push @b, 5, $i==@$fcols-1 ? 3:2, 1;
        }
        $draw_bch->(@b);
        push @s, "\n";
    }

    join "", @s;
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

=item * Unicode and wide character support

Border styles using Unicode characters (double lines, bold/heavy lines, brick
style, etc). Columns containing wide characters stay aligned.

=back

Compared to Text::ASCIITable, it uses C<lower_case> method/attr names instead of
C<CamelCase>, and it uses arrayref for C<columns> and C<add_row>. When
specifying border styles, the order of characters are slightly different. More
fine-grained options to customize appearance.

It uses L<Moo> object system.


=head1 BORDER STYLES

To list available border styles:

 say $_ for $t->list_border_styles;

Or you can also try out borders using the provided
B<ansitable-list-border-styles> script.

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

Each character must have visual width of 1. But if A is an empty string, the top
border line will not be drawn. Likewise: if H is an empty string, the
header-data separator line will not be drawn; if O is an empty string, data
separator lines will not be drawn; if S is an empty string, bottom border line
will not be drawn.


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
modules for example, like L<Text::ANSITable::ColorTheme::Default>. Each color
specified in the specification must be ANSI escape codes (e.g. "\e[31;1m" for
bold red, or "\e[38;5;226m" for lemon yellow.


=head1 COLUMN WIDTHS

By default column width is set just so it is enough to show the widest data.
Also by default terminal width is respected, so columns are shrunk
proportionally to fit terminal width.

You can set certain column's width using the C<column_style()> method, e.g.:

 $t->column_style('colname', width => 20);

You can also use negative number here to mean I<minimum> width.


=head1 CELL (HORIZONTAL) PADDING

By default cell (horizontal) padding is 1. This can be customized in the
following ways (in order of precedence, from lowest):

=over

=item * Setting C<column_pad> attribute

This sets left and right padding for all columns.

=item * Setting C<column_lpad> and C<column_rpad> attributes

They set left and right padding, respectively.

=item * Setting per-column padding using C<column_style()> method

Example:

 $t->column_style('colname', pad => 2);

=item * Setting per-column left/right padding using C<column_style()> method

 $t->column_style('colname', lpad => 0);
 $t->column_style('colname', lpad => 1);

=back


=head1 COLUMN VERTICAL PADDING

Default vertical padding is 0. This can be changed in the following ways (in
order of precedence, from lowest):

=over

=item * Setting C<row_vpad> attribute

This sets top and bottom padding.

=item * Setting C<row_tpad>/<row_bpad> attribute

They set top/bottom padding separately.

=item * Setting per-row vertical padding using C<row_style()>/C<add_row(s)> method

Example:

 $t->row_style($rownum, vpad => 1);

When adding row:

 $t->add_row($rownum, {vpad=>1});

=item * Setting per-row vertical padding using C<row_style()>/C<add_row(s)> method

Example:

 $t->row_style($rownum, tpad => 1);
 $t->row_style($rownum, bpad => 2);

When adding row:

 $t->add_row($row, {tpad=>1, bpad=>2});

=back


=head1 CELL COLORS

By default data format colors are used, e.g. cyan/green for text (using the
default color scheme). In absense of that, default_fgcolor and default_bgcolor
from the color scheme are used. You can customize colors in the following ways
(ordered by precedence, from lowest):

=over

=item * C<cell_fgcolor> and C<cell_bgcolor> attributes

Sets all cells' colors. Color should be specified using 6-hexdigit RGB which
will be converted to the appropriate terminal color.

Can also be set to a coderef which will receive ($rownum, $colname) and should
return an RGB color.

=item * Per-column color using C<column_style()> method

Example:

 $t->column_style('colname', fgcolor => 'fa8888');
 $t->column_style('colname', bgcolor => '202020');

=item Per-row color using C<row_style()> method

Example:

 $t->row_style($rownum, fgcolor => 'fa8888');
 $t->row_style($rownum, bgcolor => '202020');

When adding row/rows:

 $t->add_row($row, {fgcolor=>..., bgcolor=>...});
 $t->add_rows($rows, {bgcolor=>...});

=item Per-cell color using C<cell_style()> method

Example:

 $t->cell_style($rownum, $colname, fgcolor => 'fa8888');
 $t->cell_style($rownum, $colname, bgcolor => '202020');

=back


=head1 CELL (HORIZONTAL AND VERTICAL) ALIGNMENT

By default colors are added according to data formats, e.g. right align for
numbers, left for strings, and middle for bools. To customize it, use the
following ways (ordered by precedence, from lowest):

=over

=item * Setting per-column alignment using C<column_style()> method

Example:

 $t->column_style($colname, align  => 'middle'); # or left, or right
 $t->column_style($colname, valign => 'top');    # or bottom, or middle

=item * Setting per-cell alignment using C<cell_style()> method

 $t->cell_style($rownum, $colname, align  => 'middle');
 $t->cell_style($rownum, $colname, valign => 'top');

=back


=head1 COLUMN WRAPPING

By default column wrapping is turned on. You can set it on/off via the
C<column_wrap> attribute or per-column C<wrap> style.

Note that cell content past the column width will be clipped/truncated.


=head1 CELL FORMATS

The formats settings regulates how the data is formatted. The value for this
setting will be passed to L<Data::Unixish::Apply>'s apply(), as the C<functions>
argument. So it should be a single string (like C<date>) or an array (like C<<
['date', ['centerpad', {width=>20}]] >>).

See L<Data::Unixish> or install L<App::dux> and then run C<dux -l> to see what
functions are available. Functions of interest to formatting data include: bool,
num, sprintf, sprintfn, wrap, (among others).


=head1 ATTRIBUTES

=head2 rows => ARRAY OF ARRAY OF STR

Store row data.

=head2 columns => ARRAY OF STR

Store column names.

=head2 row_filter => CODE|ARRAY OF INT

When drawing, only show rows that match this. Can be a coderef which will
receive ($row, $i) and should return bool (true means show this row). Or, can be
an array which contains indices of rows that should be shown (e.g. C<< [0, 1, 3,
4] >>).

=head2 column_filter => CODE|ARRAY OF STR

When drawing, only show columns that match this. Can be a coderef which will
receive C<< ($colname, $colidx) >> and should return bool (true means show this
column). Or, can be an array which contains names of columns that should be
shown (e.g. C<< ['num', 'size'] >>). The array form can also be used to reorder
columns or show a column multiple times (e.g. C<< ['num', ..., 'num'] >> for
display.

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

=head2 show_header => BOOL (default: 1)

When drawing, whether to show header.

=head2 show_row_separator => BOOL (default: 0)

When drawing, whether to show separator between rows.

=head2 column_pad => INT

Set (horizontal) padding for all columns. Can be overriden by per-column C<pad>
style.

=head2 column_lpad => INT

Set left padding for all columns. Overrides the C<column_pad> attribute. Can be
overriden by per-column <lpad> style.

=head2 column_rpad => INT

Set right padding for all columns. Overrides the C<column_pad> attribute. Can be
overriden by per-column <rpad> style.

=head2 row_vpad => INT

Set vertical padding for all rows. Can be overriden by per-row C<vpad> style.

=head2 row_tpad => INT

Set top padding for all rows. Overrides the C<row_vpad> attribute. Can be
overriden by per-row <tpad> style.

=head2 row_bpad => INT

Set bottom padding for all rows. Overrides the C<row_vpad> attribute. Can be
overriden by per-row <bpad> style.

=head2 cell_fgcolor => RGB|CODE

Set foreground color for all cells. Value should be 6-hexdigit RGB. Can also be
a coderef that will receive ($row_num, $colname) and should return an RGB color.
Can be overriden by per-cell C<fgcolor> style.

=head2 cell_bgcolor => RGB|CODE

Like C<cell_fgcolor> but for background color.


=head1 METHODS

=head2 $t = Text::ANSITable->new(%attrs) => OBJ

Constructor.

=head2 $t->list_border_styles => LIST

Return the names of available border styles. Border styles will be searched in
C<Text::ANSITable::BorderStyle::*> modules.

=head2 $t->add_row(\@row[, \%styles]) => OBJ

Add a row. Note that row data is not copied, only referenced.

Can also add per-row styles (which can also be done using C<row_style()>).

=head2 $t->add_rows(\@rows[, \%styles]) => OBJ

Add multiple rows. Note that row data is not copied, only referenced.

Can also add per-row styles (which can also be done using C<row_style()>).

=head2 $t->add_row_separator() => OBJ

Add a row separator line.

=head2 $t->cell($row_num, $col[, $newval]) => VAL

Get or set cell value at row #C<$row_num> (starts from zero) and column #C<$col>
(if C<$col> is a number, starts from zero) or column named C<$col> (if C<$col>
does not look like a number).

When setting value, old value is returned.

=head2 $t->column_style($col, $style[, $newval]) => VAL

Get or set per-column style for column named/numbered C<$col>. Available values
for C<$style>: pad, lpad, width, formats, fgcolor, bgcolor.

When setting value, old value is returned.

=head2 $t->row_style($row_num[, $newval]) => VAL

Get or set per-row style. Available values for C<$style>: vpad, tpad, bpad,
fgcolor, bgcolor.

When setting value, old value is returned.

=head2 $t->cell_style($row_num, $col[, $newval]) => VAL

Get or set per-cell style. Available values for C<$style>: formats, fgcolor,
bgcolor.

When setting value, old value is returned.

=head2 $t->draw => STR

Render table.


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

=head2 How to hide borders?

Choose border styles like C<space> or C<none>:

 $t->border_style("none");

=head2 How do I format data?

Use the C<formats> per-column style or per-cell style. For example:

 $t->column_style('available', formats => [[bool=>{style=>'check_cross'}],
                                           [centerpad=>{width=>10}]]);
 $t->column_style('amount'   , formats => [[num=>{decimal_digits=>2}]]);
 $t->column_style('size'     , formats => [[num=>{style=>'kilo'}]]);

See L<Data::Unixish::Apply> and L<Data::Unixish> for more details on the
available formatting functions.


=head1 TODO

Attributes: header_{pad,vpad,lpad,rpad,tpad,bpad,align,valign,wrap}


=head1 SEE ALSO

Other table-formatting modules: L<Text::Table>, L<Text::SimpleTable>,
L<Text::ASCIITable> (which I usually used), L<Text::UnicodeTable::Simple>,
L<Table::Simple> (uses Moose).

Modules used: L<Text::ANSI::Util>, L<Color::ANSI::Util>.

=cut
