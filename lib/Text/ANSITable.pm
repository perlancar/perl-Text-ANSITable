package Text::ANSITable;

use 5.010001;
use strict;
use warnings;
use Log::Any '$log';
use Moo;

#use List::Util 'first';
use Scalar::Util 'looks_like_number';
use Text::ANSI::Util qw(ta_mbswidth_height ta_mbpad ta_add_color_resets);
use Color::ANSI::Util qw(ansi16fg ansi16bg
                         ansi256fg ansi256bg
                         ansi24bfg ansi24bbg
                         detect_color_depth
                    );

# VERSION

has use_color => (
    is      => 'rw',
    default => sub {
        $ENV{COLOR} // (-t STDOUT) // 1;
    },
);
has color_depth => (
    is      => 'rw',
    default => sub {
        return $ENV{COLOR_DEPTH} if defined $ENV{COLOR_DEPTH};
        return detect_color_depth() // 16;
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
    default => sub { 2 },
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
    is      => 'rw',
);
has color_theme_args => (
    is      => 'rw',
    default => sub { {} },
);
has border_style_args => (
    is      => 'rw',
    default => sub { {} },
);
has header_align => (
    is      => 'rw',
);
has header_valign => (
    is      => 'rw',
);
has header_vpad => (
    is      => 'rw',
);
has header_tpad => (
    is      => 'rw',
);
has header_bpad => (
    is      => 'rw',
);
has header_fgcolor => (
    is      => 'rw',
);
has header_bgcolor => (
    is      => 'rw',
);

sub BUILD {
    my ($self, $args) = @_;

    # pick a default border style
    unless ($self->{border_style}) {
        my $bs;
        if (defined $ENV{ANSITABLE_BORDER_STYLE}) {
            $bs = $ENV{ANSITABLE_BORDER_STYLE};
        } elsif ($self->{use_utf8}) {
            $bs = 'bricko';
        } elsif ($self->{use_box_chars}) {
            $bs = 'single_boxchar';
        } else {
            $bs = 'single_ascii';
        }
        $self->border_style($bs);
    }

    # pick a default color theme
    unless ($self->{color_theme}) {
        my $ct;
        if (defined $ENV{ANSITABLE_COLOR_THEME}) {
            $ct = $ENV{ANSITABLE_COLOR_THEME};
        } elsif ($self->{use_color}) {
            if ($self->{color_depth} >= 2**24) {
                $ct = 'default_gradation';
            } else {
                $ct = 'default_nogradation';
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
                $bs->{$_}{module} = $mod;
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
                $ct->{$_}{module} = $mod;
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
        my $bss;
        my $pkg;
        if ($bs =~ s/(.+):://) {
            $pkg = $1;
            my $pkgp = $pkg; $pkgp =~ s!::!/!g;
            require "Text/ANSITable/BorderStyle/$pkgp.pm";
            no strict 'refs';
            $bss = \%{"Text::ANSITable::BorderStyle::$pkg\::border_styles"};
        } else {
            $bss = $self->list_border_styles(1);
        }
        $bss->{$bs} or die "Unknown border style name '$bs'".
            ($pkg ? " in package Text::ANSITable::BorderStyle::$pkg" : "");
        $bs = $bss->{$bs};
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

    my $p2;
    if (!ref($ct)) {
        $p2 = " named $ct";
        my $cts;
        my $pkg;
        if ($ct =~ s/(.+):://) {
            $pkg = $1;
            my $pkgp = $pkg; $pkgp =~ s!::!/!g;
            require "Text/ANSITable/ColorTheme/$pkgp.pm";
            no strict 'refs';
            $cts = \%{"Text::ANSITable::ColorTheme::$pkg\::color_themes"};
        } else {
            $cts = $self->list_color_themes(1);
        }
        $cts->{$ct} or die "Unknown color theme name '$ct'".
            ($pkg ? " in package Text::ANSITable::ColorTheme::$pkg" : "");
        $ct = $cts->{$ct};
    }

    my $err;
    if (!$ct->{no_color} && !$self->use_color) {
        $err = "color theme uses color but use_color is set to false";
    }
    die "Can't select color theme$p2: $err" if $err;

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
# in _draw (draw data) attribute.
sub _prepare_draw {
    my $self = shift;

    $self->{_draw} = {};
    $self->{_draw}{y} = 0; # current line
    $self->{_draw}{buf} = [];

    # ansi codes to set and reset line-drawing mode.
    {
        my $bs = $self->{border_style};
        $self->{_draw}{set_line_draw_mode}   = $bs->{box_chars} ? "\e(0" : "";
        $self->{_draw}{reset_line_draw_mode} = $bs->{box_chars} ? "\e(B" : "";
    }

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
    $self->{_draw}{header_height} = $header_height;

    # calculate vertical paddings of data rows
    my $frow_tpads  = []; # index = [frowidx]
    my $frow_bpads  = []; # ditto
    my $frows = [];
    my $frow_separators = [];
    my $frow_orig_indices = []; # needed when accessing original row data
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
            push @$frow_orig_indices, $i;
        }
    }
    $self->{_draw}{fcols}             = $fcols;
    $self->{_draw}{frow_separators}   = $frow_separators;
    $self->{_draw}{frow_tpads}        = $frow_tpads;
    $self->{_draw}{frow_bpads}        = $frow_bpads;
    $self->{_draw}{frow_orig_indices} = $frow_orig_indices;

    # XXX detect column type from data/header name. assign default column align,
    # valign, fgcolor, bgcolor, formats.
    my $fcol_detect = [];
    #{
    #    # ...
    #}
    $self->{_draw}{fcol_detect} = $fcol_detect;

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
            my $fmts = $self->column_style($i, 'formats') //
                $fcol_detect->[$i]{formats};
            if (defined $fmts) {
                require Data::Unixish::Apply;
                my $res = Data::Unixish::Apply::apply(
                    in => [map {$frows->[$_][$i]} 0..@$frows-1],
                    functions => $fmts,
                );
                die "Can't format column $cols->[$i]: $res->[0] - $res->[1]"
                    unless $res->[0] == 200;
                $res = $res->[2];
                for (0..@$frows-1) { $frows->[$_][$i] = $res->[$_] // "" }
            }
            $fcol_lpads->[$i] = $self->column_style($i, 'lpad') //
                $self->column_style($i, 'pad') // $lpad;
            $fcol_rpads->[$i] = $self->column_style($i, 'rpad') //
                $self->column_style($i, 'pad') // $rpad;
        }
    }
    $self->{_draw}{fcol_lpads}  = $fcol_lpads;
    $self->{_draw}{fcol_rpads}  = $fcol_rpads;

    # apply cell formats, calculate widths/heights of data rows
    my $frow_heights  = []; # index = [frowidx]
    #my $fcell_heights = []; # index = [frowidx][colnum]
    {
        my $tpad = $self->{row_tpad} // $self->{row_vpad}; # tbl-lvl tpad
        my $bpad = $self->{row_bpad} // $self->{row_vpad}; # tbl-lvl bpad
        my $cswidths  = [map {$self->column_style($_, 'width')} 0..@$cols-1];
        my $val;
        for my $i (0..@$frows-1) {
            my %seen;
            my $origi = $frow_orig_indices->[$i];
            my $rsheight = $self->row_style($origi, 'height');
            for my $j (0..@$cols-1) {
                next unless $cols->[$j] ~~ $fcols;
                next if $seen{$cols->[$j]}++;

                # apply cell-level formats
                my $fmts = $self->cell_style($i, $j, 'formats');
                if (defined $fmts) {
                    require Data::Unixish::Apply;
                    my $res = Data::Unixish::Apply::apply(
                        in => [ $rows->[$origi][$j] ],
                        functions => $fmts,
                    );
                    die "Can't format cell ($origi, $cols->[$j]): ".
                        "$res->[0] - $res->[1]" unless $res->[0] == 200;
                    $frows->[$i][$j] = $res->[2][0];
                }

                # calculate heights/widths of data
                my $wh = ta_mbswidth_height($frows->[$i][$j]);
                #$fcell_heights->[$i][$j] = $wh->[1];

                $val = $wh->[1];
                if (defined $rsheight) {
                    if ($rsheight < 0) {
                        # widen to minimum height
                        $val = -$rsheight if $val < -$rsheight;
                    } else {
                        $val =  $rsheight if $val <  $rsheight;
                    }
                }
                $frow_heights->[$i] = $val if !defined($frow_heights->[$i]) ||
                    $frow_heights->[$i] < $val;

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

            } # col
        }
    }
    $self->{_draw}{frow_heights}  = $frow_heights;
    #$self->{_draw}{fcell_heights} = $fcell_heights;
    $self->{_draw}{fcol_widths}   = $fcol_widths;
    $self->{_draw}{frows}         = $frows;

    # calculate table width and height
    {
        my $w = 0;
        $w += 1 if length($self->get_border_char(3, 0));
        my $has_vsep = length($self->get_border_char(3, 1));
        for my $i (0..@$cols-1) {
            next unless $cols->[$i] ~~ $fcols;
            $w += $fcol_lpads->[$i] + $fcol_widths->[$i] + $fcol_rpads->[$i];
            if ($i < @$cols-1) {
                $w += 1 if $has_vsep;
            }
        }
        $w += 1 if length($self->get_border_char(3, 2));
        $self->{_draw}{table_width}  = $w;

        my $h = 0;
        $h += 1 if length($self->get_border_char(0, 0)); # top border line
        $h += $self->{header_tpad} // $self->{header_vpad} //
                   $self->{row_tpad} // $self->{row_vpad};
        $h += $header_height;
        $h += $self->{header_bpad} // $self->{header_vpad} //
                   $self->{row_bpad} // $self->{row_vpad};
        $h += 1 if length($self->get_border_char(2, 0));
        for my $i (0..@$frows-1) {
            $h += $frow_tpads->[$i] + $frow_heights->[$i] + $frow_bpads->[$i];
            $h += 1 if $self->_should_draw_row_separator($i);
        }
        $h += 1 if length($self->get_border_char(5, 0));
        $self->{_draw}{table_height}  = $h;
    }
}

# push string into the drawing buffer. also updates "cursor" position.
sub draw_str {
    my $self = shift;
    # currently x position is not recorded because this involves doing
    # ta_mbswidth() (or ta_mbswidth_height()) for every string, which is rather
    # expensive. so only the y position is recorded by counting newlines.

    for (@_) {
        my $num_nl = 0;
        $num_nl++ while /\r?\n/og;
        push @{$self->{_draw}{buf}}, $_;
        $self->{_draw}{y} += $num_nl;
    }
    $self;
}

# pick border character from border style. args is a hashref to be supplied to
# the coderef if the 'chars' value from the style is a coderef.
sub get_border_char {
    my ($self, $y, $x, $n, $args) = @_;
    my $bch = $self->{border_style}{chars};
    $n //= 1;
    if (ref($bch) eq 'CODE') {
        $bch->($self, y=>$y, x=>$x, n=>$n, %{$args // {}});
    } else {
        $bch->[$y][$x] x $n;
    }
}

# convert an RGB color (or a coderef that generates an RGB color) to ANSI escape
# code. args is a hashref to be supplied to coderef as arguments.
sub color2ansi {
    my ($self, $c, $args, $is_bg) = @_;

    # already ansi, skip

    $args //= {};

    if (ref($c) eq 'CODE') {
        $c = $c->($self, %$args);
    }

    unless (index($c, "\e[") >= 0) {
        if ($self->{color_depth} >= 2**24) {
            if (ref($c) eq 'ARRAY') {
                $c = (defined($c->[0]) ? ansi24bfg($c->[0]) : "") .
                    (defined($c->[1]) ? ansi24bbg($c->[1]) : "");
            } else {
                $c = $is_bg ? ansi24bbg($c) : ansi24bfg($c);
            }
        } elsif ($self->{color_depth} >= 256) {
            if (ref($c) eq 'ARRAY') {
                $c = (defined($c->[0]) ? ansi256fg($c->[0]) : "") .
                    (defined($c->[1]) ? ansi256bg($c->[1]) : "");
            } else {
                $c = $is_bg ? ansi256bg($c) : ansi256fg($c);
            }
        } else {
            if (ref($c) eq 'ARRAY') {
                $c = (defined($c->[0]) ? ansi16fg($c->[0]) : "") .
                    (defined($c->[1]) ? ansi16bg($c->[1]) : "");
            } else {
                $c = $is_bg ? ansi16bg($c) : ansi16fg($c);
            }
        }
    }
    $c;
}

# pick color from color theme
sub get_theme_color {
    my ($self, $name, $args) = @_;

    return "" if $self->{color_theme}{no_color};
    my $c = $self->{color_theme}{colors}{$name};
    return "" unless defined($c) && length($c);

    $self->color2ansi($c, {name=>$name, %{ $args // {} }}, $name =~ /_bg$/);
}

sub draw_theme_color {
    my $self = shift;
    my $c = $self->get_theme_color(@_);
    $self->draw_str($c) if length($c);
}

sub get_color_reset {
    my $self = shift;
    return "" if $self->{color_theme}{no_color};
    "\e[0m";
}

sub draw_color_reset {
    my $self = shift;
    my $c = $self->get_color_reset;
    $self->draw_str($c) if length($c);
}

# draw border character(s). drawing border character involves setting border
# color, setting drawing mode (for boxchar styles), aside from drawing the
# actual characters themselves. arguments are list of (y, x, n) tuples where y
# and x are the row and col number of border character, n is the number of
# characters to print. n defaults to 1 if not specified.
sub draw_border_char {
    my $self = shift;
    my $args = shift if ref($_[0]) eq 'HASH';

    $self->draw_str($self->{_draw}{set_line_draw_mode});
    while (my ($y, $x, $n) = splice @_, 0, 3) {
        $n //= 1;
        if ($args) {
            $self->draw_theme_color('border',
                                    {border=>[$y, $x, $n], %$args});
        } else {
            $self->draw_theme_color('border',
                                    {border=>[$y, $x, $n]});
        }
        $self->draw_str($self->get_border_char($y, $x, $n));
        $self->draw_color_reset;
    }
    $self->draw_str($self->{_draw}{reset_line_draw_mode});
}

sub _should_draw_row_separator {
    my ($self, $i) = @_;

    return $i < @{$self->{_draw}{frows}}-1 &&
        (($self->{show_row_separator}==2 && $i~~$self->{_draw}{frow_separators})
             || $self->{show_row_separator}==1);
}

# apply align/valign, padding, and then default fgcolor/bgcolor to text
sub _get_cell_lines {
    my $self = shift;
    #say "D: get_cell_lines ".join(", ", map{$_//""} @_);
    my ($text, $width, $height, $align, $valign,
        $lpad, $rpad, $tpad, $bpad, $color) = @_;

    my @lines;
    push @lines, "" for 1..$tpad;
    my @dlines = split /\r?\n/, $text;
    my ($la, $lb);
    $valign //= 'top';
    if ($valign =~ /^[Bb]/o) { # bottom
        $la = $height-@dlines;
        $lb = 0;
    } elsif ($valign =~ /^[MmCc]/o) { # middle/center
        $la = int(($height-@dlines)/2);
        $lb = $height-@dlines-$la;
    } else { # top
        $la = 0;
        $lb = $height-@dlines;
    }
    push @lines, "" for 1..$la;
    push @lines, @dlines;
    push @lines, "" for 1..$lb;
    push @lines, "" for 1..$bpad;

    $align //= 'left';
    my $pad = $align =~ /^[Ll]/o ? "right" :
        ($align =~ /^[Rr]/o ? "left" : "center");

    @lines = ta_add_color_resets(@lines);
    for (@lines) {
        $_ = (" "x$lpad) . ta_mbpad($_, $width, $pad, " ", 1) . (" "x$rpad);
        # add default color
        s/\e\[0m(?=.)/\e[0m$color/g;
        $_ = $color . $_;
    }

    \@lines;
}

sub _get_header_cell_lines {
    my ($self, $i) = @_;

    my $ct = $self->{color_theme};

    my $fgcolor;
    if (defined $self->{header_fgcolor}) {
        $fgcolor = $self->color2ansi($self->{header_fgcolor});
    } elsif (defined $self->{cell_fgcolor}) {
        $fgcolor = $self->color2ansi($self->{cell_fgcolor});
    } elsif (defined $self->{_draw}{fcol_detect}[$i]{fgcolor}) {
        $fgcolor = $self->color2ansi($self->{_draw}{fcol_detect}[$i]{fgcolor});
    } elsif (defined $ct->{colors}{header}) {
        $fgcolor = $self->get_theme_color('header');
    } elsif (defined $ct->{colors}{cell}) {
        $fgcolor = $self->get_theme_color('cell');
    } else {
        $fgcolor = "";
    }

    my $bgcolor;
    if (defined $self->{header_bgcolor}) {
        $bgcolor = $self->color2ansi($self->{header_bgcolor},
                                     undef, 1);
    } elsif (defined $self->{cell_bgcolor}) {
        $bgcolor = $self->color2ansi($self->{cell_bgcolor},
                                     undef, 1);
    } elsif (defined $self->{_draw}{fcol_detect}[$i]{bgcolor}) {
        $fgcolor = $self->color2ansi($self->{_draw}{fcol_detect}[$i]{bgcolor},
                                     undef, 1);
    } elsif (defined $ct->{colors}{header_bg}) {
        $bgcolor = $self->get_theme_color('header_bg');
    } elsif (defined $ct->{colors}{cell_bg}) {
        $bgcolor = $self->get_theme_color('cell_bg');
    } else {
        $bgcolor = "";
    }

    my $align  = $self->{_draw}{fcol_detect}[$i]{align} //
        $self->{header_align}  // $self->{column_align};
    my $valign = $self->{_draw}{fcol_detect}[$i]{valign} //
        $self->{header_valign} // $self->{row_valign};

    my $lpad = $self->{_draw}{fcol_lpads}[$i];
    my $rpad = $self->{_draw}{fcol_rpads}[$i];
    my $tpad = $self->{header_tpad} // $self->{header_vpad} // 0;
    my $bpad = $self->{header_bpad} // $self->{header_vpad} // 0;

    #say "D:header cell: i=$i, col=$self->{columns}[$i], fgcolor=$fgcolor, bgcolor=$bgcolor";
    $self->_get_cell_lines(
        $self->{columns}[$i],            # text
        $self->{_draw}{fcol_widths}[$i], # width
        $self->{_draw}{header_height},   # height
        $align, $valign,                 # aligns
        $lpad, $rpad, $tpad, $bpad,      # paddings
        $fgcolor . $bgcolor);
}

sub _get_data_cell_lines {
    my ($self, $y, $x) = @_;

    my $ct = $self->{color_theme};
    my $oy = $self->{_draw}{frow_orig_indices}[$y];

    my $tmp;
    my $fgcolor;
    if (defined ($tmp = $self->cell_style($oy, $x, 'fgcolor'))) {
        $fgcolor = $self->color2ansi($tmp);
    } elsif (defined ($tmp = $self->row_style($oy, 'fgcolor'))) {
        $fgcolor = $self->color2ansi($tmp);
    } elsif (defined ($tmp = $self->column_style($x, 'fgcolor'))) {
        $fgcolor = $self->color2ansi($tmp);
    } elsif (defined ($tmp = $self->{cell_fgcolor})) {
        $fgcolor = $self->color2ansi($tmp);
    } elsif (defined ($tmp = $self->{_draw}{fcol_detect}[$x]{fgcolor})) {
        $fgcolor = $self->color2ansi($tmp);
    } elsif (defined $ct->{colors}{cell}) {
        $fgcolor = $self->get_theme_color('cell');
    } else {
        $fgcolor = "";
    }

    my $bgcolor;
    if (defined ($tmp = $self->cell_style($oy, $x, 'bgcolor'))) {
        $bgcolor = $self->color2ansi($tmp,
                                     undef, 1);
    } elsif (defined ($tmp = $self->row_style($oy, 'bgcolor'))) {
        $bgcolor = $self->color2ansi($tmp,
                                     undef, 1);
    } elsif (defined ($tmp = $self->column_style($x, 'bgcolor'))) {
        $bgcolor = $self->color2ansi($tmp,
                                     undef, 1);
    } elsif (defined ($tmp = $self->{cell_bgcolor})) {
        $bgcolor = $self->color2ansi($tmp,
                                     undef, 1);
    } elsif (defined ($tmp = $self->{_draw}{fcol_detect}[$x]{bgcolor})) {
        $bgcolor = $self->color2ansi($tmp,
                                     undef, 1);
    } elsif (defined $ct->{colors}{cell_bg}) {
        $bgcolor = $self->get_theme_color('cell_bg');
    } else {
        $bgcolor = "";
    }

    my $align  = $self->{_draw}{fcol_detect}[$x]{align} //
        $self->column_style($x, 'align') // $self->{column_align};
    my $valign = $self->{_draw}{fcol_detect}[$x]{valign} //
        $self->column_style($x, 'valign') // $self->{row_valign};

    my $lpad = $self->{_draw}{fcol_lpads}[$x];
    my $rpad = $self->{_draw}{fcol_rpads}[$x];
    my $tpad = $self->{_draw}{frow_tpads}[$y];
    my $bpad = $self->{_draw}{frow_bpads}[$y];

    #say "D:oy=$oy, y=$y, x=$x, fgcolor=$fgcolor, bgcolor=$bgcolor";
    $self->_get_cell_lines(
        $self->{_draw}{frows}[$y][$x],    # text
        $self->{_draw}{fcol_widths}[$x],  # width
        $self->{_draw}{frow_heights}[$y], # height
        $align, $valign,                  # aligns
        $lpad, $rpad, $tpad, $bpad,       # paddings
        $fgcolor . $bgcolor);
}

sub draw {
    my ($self) = @_;

    $self->_prepare_draw;

    my $cols  = $self->{cols};
    my $fcols = $self->{_draw}{fcols};
    my $frows = $self->{_draw}{frows};
    my $frow_heights    = $self->{_draw}{frow_heights};
    #my $cell_heights    = $self->{_draw}{fcell_heights};
    my $frow_tpads      = $self->{_draw}{frow_tpads};
    my $frow_bpads      = $self->{_draw}{frow_bpads};
    my $fcol_lpads      = $self->{_draw}{fcol_lpads};
    my $fcol_rpads      = $self->{_draw}{fcol_rpads};
    my $fcol_widths     = $self->{_draw}{fcol_widths};

    # draw border top line
    {
        last unless length($self->get_border_char(0, 0));
        my @b;
        push @b, 0, 0, 1;
        for my $i (0..@$fcols-1) {
            my $ci = $self->_colidx($fcols->[$i]);
            push @b, 0, 1,
                $fcol_lpads->[$ci] + $fcol_widths->[$ci] + $fcol_rpads->[$ci];
            push @b, 0, $i==@$fcols-1 ? 3:2, 1;
        }
        $self->draw_border_char(@b);
        $self->draw_str("\n");
    }

    # draw header
    if ($self->{show_header}) {
        my %seen;
        my $hcell_lines = []; # index = [fcolnum]
        for my $i (0..@$fcols-1) {
            my $ci = $self->_colidx($fcols->[$i]);
            if (defined($seen{$i})) {
                $hcell_lines->[$i] = $hcell_lines->[$seen{$i}];
            }
            $seen{$i} = $ci;
            $hcell_lines->[$i] = $self->_get_header_cell_lines($ci);
        }
        if (@$fcols) {
            for my $l (0..@{ $hcell_lines->[0] }-1) {
                $self->draw_border_char(1, 0);
                for my $i (0..@$fcols-1) {
                    $self->draw_str($hcell_lines->[$i][$l]);
                    $self->draw_color_reset;
                    $self->draw_border_char(1, $i == @$fcols-1 ? 2:1);
                }
                $self->draw_str("\n");
            }
        }
    }

    # draw header-data row separator
    if ($self->{show_header} && length($self->get_border_char(2, 0))) {
        my @b;
        push @b, 2, 0, 1;
        for my $i (0..@$fcols-1) {
            my $ci = $self->_colidx($fcols->[$i]);
            push @b, 2, 1,
                $fcol_lpads->[$ci] + $fcol_widths->[$ci] + $fcol_rpads->[$ci];
            push @b, 2, $i==@$fcols-1 ? 3:2, 1;
        }
        $self->draw_border_char(@b);
        $self->draw_str("\n");
    }

    # draw data rows
    {
        for my $r (0..@$frows-1) {
            my $dcell_lines = []; # index = [fcolnum]
            my %seen;
            for my $i (0..@$fcols-1) {
                my $ci = $self->_colidx($fcols->[$i]);
                if (defined($seen{$i})) {
                    $dcell_lines->[$i] = $dcell_lines->[$seen{$i}];
                }
                $seen{$i} = $ci;
                $dcell_lines->[$i] = $self->_get_data_cell_lines($r, $ci);
            }

            if (@$fcols) {
                for my $l (0..@{ $dcell_lines->[0] }-1) {
                    $self->draw_border_char({row_idx=>$r}, 3, 0);
                    for my $i (0..@$fcols-1) {
                        $self->draw_str($dcell_lines->[$i][$l]);
                        $self->draw_color_reset;
                        $self->draw_border_char({row_idx=>$r},
                                                3, $i == @$fcols-1 ? 2:1);
                    }
                    $self->draw_str("\n");
                }
            }

            # draw separators between row
            if ($self->_should_draw_row_separator($r)) {
                my @b;
                push @b, 4, 0, 1;
                for my $i (0..@$fcols-1) {
                    my $ci = $self->_colidx($fcols->[$i]);
                    push @b, 4, 1,
                        $fcol_lpads->[$ci] + $fcol_widths->[$ci] +
                            $fcol_rpads->[$ci];
                    push @b, 4, $i==@$fcols-1 ? 3:2, 1;
                }
                $self->draw_border_char({row_idx=>$r}, @b);
                $self->draw_str("\n");
            }
        } # for frow
    }

    # draw border bottom line
    {
        last unless length($self->get_border_char(5, 0));
        my @b;
        push @b, 5, 0, 1;
        for my $i (0..@$fcols-1) {
            my $ci = $self->_colidx($fcols->[$i]);
            push @b, 5, 1,
                $fcol_lpads->[$ci] + $fcol_widths->[$ci] + $fcol_rpads->[$ci];
            push @b, 5, $i==@$fcols-1 ? 3:2, 1;
        }
        $self->draw_border_char(@b);
        $self->draw_str("\n");
    }

    join "", @{$self->{_draw}{buf}};
}

1;
#ABSTRACT: Create a nice formatted table using extended ASCII and ANSI colors

=for Pod::Coverage ^(BUILD|draw_.+|color2ansi|get_theme_color|get_border_char)$

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

 # draw it!
 say $t->draw;


=head1 DESCRIPTION

This module is yet another text table formatter module like L<Text::ASCIITable>
or L<Text::SimpleTable>, with the following differences:

=over

=item * Colors and color themes

ANSI color codes will be used by default (even 256 and 24bit colors), but will
degrade to lower color depth and black/white according to terminal support.

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
can also set the C<ANSITABLE_BORDER_STYLE> environment variable to set the
default.

When there are lots of C<Text::ANSITable::BorderStyle::*> modules, searching can
add some overhead. To avoid searching in all modules, you can specify name using
C<Subpackage::Name> syntax, e.g.:

 # will only search in Text::ANSITable::BorderStyle::Default
 $t->color_theme("Default::bricko");

To create a new border style, create a module under
C<Text::ANSITable::BorderStyle::>. Please see one of the existing border style
modules for example, like L<Text::ANSITable::BorderStyle::Default>. Format for
the C<chars> specification key:

 [
   [A, b, C, D],  # 0
   [E, F, G],     # 1
   [H, i, J, K],  # 2
   [L, M, N],     # 3
   [O, p, Q, R],  # 4
   [S, t, U, V],  # 5
 ]

 AbbbCbbbD        #0 Top border characters
 E   F   G        #1 Vertical separators for header row
 HiiiJiiiK        #2 Separator between header row and first data row
 L   M   N        #3 Vertical separators for data row
 OpppQpppR        #4 Separator between data rows
 L   M   N        #3
 StttUtttV        #5 Bottom border characters

Each character must have visual width of 1. But if A is an empty string, the top
border line will not be drawn. Likewise: if H is an empty string, the
header-data separator line will not be drawn; if S is an empty string, bottom
border line will not be drawn.


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
also set the C<ANSITABLE_COLOR_THEME> environment variable to set the default.

When there are lots of C<Text::ANSITable::ColorTheme::*> modules, searching can
add some overhead. To avoid searching in all modules, you can specify name using
C<Subpackage::Name> syntax, e.g.:

 # will only search in Text::ANSITable::ColorTheme::Default
 $t->color_theme("Default::default_256");

To create a new color theme, create a module under
C<Text::ANSITable::ColorTheme::>. Please see one of the existing color theme
modules for example, like L<Text::ANSITable::ColorTheme::Default>. Color for
items must be specified as 6-hexdigit RGB value (like C<ff0088>) or ANSI escape
codes (e.g. "\e[31;1m" for bold red foregound color, or "\e[48;5;226m" for lemon
yellow background color). You can also return a 2-element array containing RGB
value for foreground and background, respectively.

For flexibility, color can also be a coderef which should produce a color value.
This allows you to do, e.g. gradation border color, random color, etc (see
L<Text::ANSITable::ColorTheme::Demo>). Code will be called with ($self, %args)
where %args contains various information, like C<name> (the item name being
requested). You can get the row position from C<< $self->{_draw}{y} >>.


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

=item * Per-row color using C<row_style()> method

Example:

 $t->row_style($rownum, fgcolor => 'fa8888');
 $t->row_style($rownum, bgcolor => '202020');

When adding row/rows:

 $t->add_row($row, {fgcolor=>..., bgcolor=>...});
 $t->add_rows($rows, {bgcolor=>...});

=item * Per-cell color using C<cell_style()> method

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

=head2 color_depth => INT

Terminal's color depth. Either 16, 256, or 2**24 (16777216). Default will be
retrieved from C<COLOR_DEPTH> environment or detected using
C<Color::ANSI::Util>'s detect_color_depth().

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

=head2 border_style_args => HASH

Some border styles can accept arguments. You can set it here.

=head2 color_theme => HASH

Color theme specification to use.

You can set this attribute's value with a specification or color theme name. See
L<"/COLOR THEMES"> for more details.

=head2 color_theme_args => HASH

Some color themes can accept arguments. You can set it here.

=head2 show_header => BOOL (default: 1)

When drawing, whether to show header.

=head2 show_row_separator => INT (default: 2)

When drawing, whether to show separator lines between rows. The default (2) is
to only show separators drawn using C<add_row_separator()>. If you set this to
1, lines will be drawn after every data row. If you set this attribute to 0, no
lines will be drawn whatsoever.

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
a coderef that will receive %args (e.g. row_idx, col_name, col_idx) and should
return an RGB color. Can be overriden by per-cell C<fgcolor> style.

=head2 cell_bgcolor => RGB|CODE

Like C<cell_fgcolor> but for background color.

=head2 header_fgcolor => RGB|CODE

Set foreground color for all headers. Overrides C<cell_fgcolor> for headers.
Value should be a 6-hexdigit RGB. Can also be a coderef that will receive %args
(e.g. col_name, col_idx) and should return an RGB color.

=head2 header_bgcolor => RGB|CODE

Like C<header_fgcolor> but for background color.

=head2 header_align => STR

=head2 header_valign => STR

=head2 header_vpad => STR

=head2 header_tpad => STR

=head2 header_bpad => STR


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

=head2 COLOR_DEPTH => INT

Can be used to set default value for the C<color_depth> attribute.

=head2 BOX_CHARS => BOOL

Can be used to set default value for the C<box_chars> attribute.

=head2 UTF8 => BOOL

Can be used to set default value for the C<utf8> attribute.

=head2 ANSITABLE_BORDER_STYLE => STR

Can be used to set default value for C<border_style> attribute.

=head2 ANSITABLE_COLOR_THEME => STR

Can be used to set default value for C<border_style> attribute.


=head1 FAQ

=head2 General

=head3 My table looks garbled when viewed through pager like B<less>!

It's because B<less> escapes ANSI color codes. Try using C<-R> option of B<less>
to display ANSI color codes raw.

Or, try not using boxchar border styles, use the utf8 or ascii version. Try not
using colors.

=head3 How do I format data?

Use the C<formats> per-column style or per-cell style. For example:

 $t->column_style('available', formats => [[bool=>{style=>'check_cross'}],
                                           [centerpad=>{width=>10}]]);
 $t->column_style('amount'   , formats => [[num=>{decimal_digits=>2}]]);
 $t->column_style('size'     , formats => [[num=>{style=>'kilo'}]]);

See L<Data::Unixish::Apply> and L<Data::Unixish> for more details on the
available formatting functions.

=head2 Border

=head3 I'm getting 'Wide character in print' error message when I use utf8 border styles!

Add something like this first before printing to your output:

 binmode(STDOUT, ":utf8");

=head3 How to hide borders?

Choose border styles like C<space_ascii> or C<none_utf8>:

 $t->border_style("none");

=head2 I want to hide borders, and I do not want row separators to be shown!

The default is for separator lines to be drawn if drawn using
C<add_row_separator()>, e.g.:

 $t->add_row(['row1']);
 $t->add_row(['row2']);
 $t->add_row_separator;
 $t->add_row(['row3']);

The result will be:

   row1
   row2
 --------
   row3

However, if you set C<show_row_separator> to 0, no separator lines will be drawn
whatsoever:

   row1
   row2
   row3

=head2 Color

=head3 How to disable colors?

Set C<use_color> attribute or C<COLOR> environment to 0.

=head3 I'm not seeing colors when output is piped (e.g. to a pager)!

The default is to disable colors when (-t STDOUT) is false. You can force-enable
colors by setting C<use_color> attribute or C<COLOR> environment to 1.

=head3 How to enable 256 colors? I'm seeing only 16 colors.

Set your C<TERM> to C<xterm-256color>. Also make sure your terminal emulator
supports 256 colors.

=head3 How to enable 24bit colors (true color)?

Currently only B<Konsole> and the Konsole-based B<Yakuake> terminal emulator
software support 24bit colors.

=head3 How to force lower color depth? (e.g. I use Konsole but want 16 colors)

Set C<COLOR_DEPTH> to 16.

=head3 How to change border gradation color?

The default color theme applies vertical color gradation to borders from white
(ffffff) to gray (444444). To change this, set C<border1> and C<border2> theme
arguments:

 $t->color_theme_args({border1=>'ff0000', border2=>'00ff00'}); # red to green


=head1 TODO/BUGS

Attributes: header_{pad,lpad,rpad,align,wrap}

Column styles: show_{left,right}_border (shorter name? {l,r}border?)

Row styles: show_{top,bottom}_border (shorter name? {t,b}border?)

row span? column span?


=head1 SEE ALSO

Other table-formatting modules: L<Text::Table>, L<Text::SimpleTable>,
L<Text::ASCIITable> (which I usually used), L<Text::UnicodeTable::Simple>,
L<Table::Simple> (uses Moose).

Modules used: L<Text::ANSI::Util>, L<Color::ANSI::Util>.

=cut
