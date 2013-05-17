package Text::ANSITable;

use 5.010001;
use strict;
use warnings;
use Log::Any '$log';
use Moo;

#use List::Util 'first';
use Color::ANSI::Util qw(ansi16fg ansi16bg
                         ansi256fg ansi256bg
                         ansi24bfg ansi24bbg
                    );
#use List::Util qw(first);
use Scalar::Util 'looks_like_number';
use Text::ANSI::Util qw(ta_mbswidth_height ta_mbpad ta_add_color_resets
                        ta_mbwrap);

# VERSION

my $ATTRS = [qw(

                  use_color color_depth use_box_chars use_utf8 columns rows
                  column_filter row_filter show_row_separator show_header
                  show_header cell_width cell_height cell_pad cell_lpad
                  cell_rpad cell_vpad cell_tpad cell_bpad cell_fgcolor
                  cell_bgcolor cell_align cell_valign header_align header_valign
                  header_vpad header_tpad header_bpad header_fgcolor
                  header_bgcolor color_theme_args border_style_args

          )];
my $STYLES = $ATTRS;
my $COLUMN_STYLES = [qw(

                          type width align valign pad lpad rpad formats fgcolor
                          bgcolor wrap

                  )];
my $ROW_STYLES = [qw(

                       height align valign vpad tpad bpad fgcolor bgcolor

               )];
my $CELL_STYLES = [qw(

                        align valign formats fgcolor bgcolor

                )];

has use_color => (
    is      => 'rw',
    default => sub {
        my $self = shift;
        $ENV{COLOR} // (-t STDOUT) //
            $self->_detect_terminal->{color_depth} > 0;
    },
);
has color_depth => (
    is      => 'rw',
    default => sub {
        my $self = shift;
        return $ENV{COLOR_DEPTH} if defined $ENV{COLOR_DEPTH};
        return $self->_detect_terminal->{color_depth} // 16;
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
        my $self = shift;
        $ENV{UTF8} //
            $self->_detect_terminal->{unicode} //
                (($ENV{LANG} // "") =~ /utf-?8/i ? 1:0);
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
has column_wrap => (
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

has cell_width => (
    is      => 'rw',
);
has cell_height => (
    is      => 'rw',
);
has cell_pad => (
    is      => 'rw',
    default => sub { 1 },
);
has cell_lpad => (
    is      => 'rw',
);
has cell_rpad => (
    is      => 'rw',
);
has cell_vpad => (
    is      => 'rw',
    default => sub { 0 },
);
has cell_tpad => (
    is      => 'rw',
);
has cell_bpad => (
    is      => 'rw',
);
has cell_fgcolor => (
    is => 'rw',
);
has cell_bgcolor => (
    is => 'rw',
);
has cell_align => (
    is => 'rw',
);
has cell_valign => (
    is => 'rw',
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

has color_theme_args => (
    is      => 'rw',
    default => sub { {} },
);
has border_style_args => (
    is      => 'rw',
    default => sub { {} },
);

my $dt_cache;
sub _detect_terminal {
    if (!$dt_cache) {
        require Term::Detect;
        $dt_cache = Term::Detect::detect_terminal("p") // {};
        #use Data::Dump; dd $dt_cache;
    }
    $dt_cache;
}

sub BUILD {
    my ($self, $args) = @_;

    # read ANSITABLE_STYLE env
    if ($ENV{ANSITABLE_STYLE}) {
        require JSON;
        my $s = JSON::decode_json($ENV{ANSITABLE_STYLE});
        for my $k (keys %$s) {
            my $v = $s->{$k};
            die "Unknown table style '$k' in ANSITABLE_STYLE environment, ".
                "please use one of [".join(", ", @$STYLES)."]"
                    unless $k ~~ $STYLES;
            $self->{$k} = $v;
        }
    }

    # pick a default border style
    unless ($self->{border_style}) {
        my $bs;
        if (defined $ENV{ANSITABLE_BORDER_STYLE}) {
            $bs = $ENV{ANSITABLE_BORDER_STYLE};
        } elsif ($self->{use_utf8}) {
            $bs = 'Default::bricko';
        } elsif ($self->{use_box_chars}) {
            $bs = 'Default::singleo_boxchar';
        } else {
            $bs = 'Default::singleo_ascii';
        }
        $self->border_style($bs);
    }

    # pick a default color theme
    unless ($self->{color_theme}) {
        my $ct;
        if (defined $ENV{ANSITABLE_COLOR_THEME}) {
            $ct = $ENV{ANSITABLE_COLOR_THEME};
        } elsif ($self->{use_color}) {
            my $bg = $self->_detect_terminal->{default_bgcolor} // '';
            if ($self->{color_depth} >= 2**24) {
                $ct = 'Default::default_gradation' .
                    ($bg eq 'ffffff' ? '_whitebg' : '');
            } else {
                $ct = 'Default::default_nogradation' .
                    ($bg eq 'ffffff' ? '_whitebg' : '');;
            }
        } else {
            $ct = 'Default::no_color';
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
                my $cutmod = $mod;
                $cutmod =~ s/^Text::ANSITable::BorderStyle:://;
                my $name = "$cutmod\::$_";
                $bs->{$_}{name} = $name;
                $all_bs->{$name} = $bs->{$_};
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
                my $cutmod = $mod;
                $cutmod =~ s/^Text::ANSITable::ColorTheme:://;
                my $name = "$cutmod\::$_";
                $ct->{$_}{name} = $name;
                $all_ct->{$name} = $ct->{$_};
            }
        }
    }

    if ($detail) {
        return $all_ct;
    } else {
        return sort keys %$all_ct;
    }
}

sub get_border_style {
    my ($self, $bs) = @_;

    my $bss;
    my $pkg;
    if ($bs =~ s/(.+):://) {
        $pkg = $1;
        my $pkgp = $pkg; $pkgp =~ s!::!/!g;
        require "Text/ANSITable/BorderStyle/$pkgp.pm";
        no strict 'refs';
        $bss = \%{"Text::ANSITable::BorderStyle::$pkg\::border_styles"};
    } else {
        #$bss = $self->list_border_styles(1);
        die "Please use SubPackage::name to choose border style, ".
            "use list_border_styles() or the provided ".
                "ansitable-list-border-styles to list available styles";
    }
    $bss->{$bs} or die "Unknown border style name '$bs'".
        ($pkg ? " in package Text::ANSITable::BorderStyle::$pkg" : "");
    $bss->{$bs};
}

sub border_style {
    my $self = shift;

    if (!@_) { return $self->{border_style} }
    my $bs = shift;

    my $p2 = "";
    if (!ref($bs)) {
        $p2 = " named $bs";
        $bs = $self->get_border_style($bs);
    }

    my $err;
    if ($bs->{box_chars} && !$self->use_box_chars) {
        $err = "use_box_chars is set to false";
    } elsif ($bs->{utf8} && !$self->use_utf8) {
        $err = "use_utf8 is set to false";
    }
    die "Can't select border style$p2: $err" if $err;

    $self->{border_style} = $bs;
}

sub get_color_theme {
    my ($self, $ct) = @_;

    my $cts;
    my $pkg;
    if ($ct =~ s/(.+):://) {
        $pkg = $1;
        my $pkgp = $pkg; $pkgp =~ s!::!/!g;
        require "Text/ANSITable/ColorTheme/$pkgp.pm";
        no strict 'refs';
        $cts = \%{"Text::ANSITable::ColorTheme::$pkg\::color_themes"};
    } else {
        #$cts = $self->list_color_themes(1);
        die "Please use SubPackage::name to choose color theme, ".
            "use list_color_themes() or the provided ".
                "ansitable-list-color-themes to list available themes";
    }
    $cts->{$ct} or die "Unknown color theme name '$ct'".
        ($pkg ? " in package Text::ANSITable::ColorTheme::$pkg" : "");
    $cts->{$ct};
}

sub color_theme {
    my $self = shift;

    if (!@_) { return $self->{color_theme} }
    my $ct = shift;

    my $p2 = "";
    if (!ref($ct)) {
        $p2 = " named $ct";
        $ct = $self->get_color_theme($ct);
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
            $self->set_row_style($i, $s, $styles->{$s});
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

sub _colnum {
    my $self = shift;
    my $colname = shift;

    return $colname if looks_like_number($colname);
    my $cols = $self->{columns};
    for my $i (0..@$cols-1) {
        return $i if $cols->[$i] eq $colname;
    }
    die "Unknown column name '$colname'";
}

sub get_cell {
    my ($self, $row_num, $col) = @_;

    $col = $self->_colnum($col);

    $self->{rows}[$row_num][$col];
}

sub set_cell {
    my ($self, $row_num, $col, $val) = @_;

    $col = $self->_colnum($col);

    my $oldval = $self->{rows}[$row_num][$col];
    $self->{rows}[$row_num][$col] = $val;
    $oldval;
}

sub get_column_style {
    my ($self, $col, $style) = @_;

    $col = $self->_colnum($col);
    $self->{_column_styles}[$col]{$style};
}

sub set_column_style {
    my $self = shift;
    my $col  = shift;

    $col = $self->_colnum($col);

    my %sets = ref($_[0]) eq 'HASH' ? %{$_[0]} : @_;

    for my $style (keys %sets) {
        my $val = $sets{$style};
        die "Unknown per-column style '$style', please use one of [".
            join(", ", @$COLUMN_STYLES) . "]" unless $style ~~ $COLUMN_STYLES;
        $self->{_column_styles}[$col]{$style} = $val;
    }
}

sub get_row_style {
    my ($self, $row, $style) = @_;

    $self->{_row_styles}[$row]{$style};
}

sub set_row_style {
    my $self = shift;
    my $row  = shift;

    my %sets = ref($_[0]) eq 'HASH' ? %{$_[0]} : @_;

    for my $style (keys %sets) {
        my $val = $sets{$style};
        die "Unknown per-row style '$style', please use one of [".
            join(", ", @$ROW_STYLES) . "]" unless $style ~~ $ROW_STYLES;
        $self->{_row_styles}[$row]{$style} = $val;
    }
}

sub get_cell_style {
    my ($self, $row, $col, $style) = @_;

    $col = $self->_colnum($col);
    $self->{_cell_styles}[$row][$col]{$style};
}

sub set_cell_style {
    my $self = shift;
    my $row  = shift;
    my $col  = shift;

    $col = $self->_colnum($col);

    my %sets = ref($_[0]) eq 'HASH' ? %{$_[0]} : @_;

    for my $style (keys %sets) {
        my $val = $sets{$style};
        die "Unknown per-cell style '$style', please use one of [".
            join(", ", @$CELL_STYLES) . "]" unless $style ~~ $CELL_STYLES;
        $self->{_cell_styles}[$row][$col]{$style} = $val;
    }
}

# detect column type from data/header name. assign default column align, valign,
# fgcolor, bgcolor, formats.
sub _detect_column_types {
    my $self = shift;

    my $cols = $self->{columns};
    my $rows = $self->{rows};
    my $ct   = $self->{color_theme};

    my $fcol_detect = [];
    my %seen;
    for my $i (0..@$cols-1) {
        my $col = $cols->[$i];
        my $res = {};
        $fcol_detect->[$i] = $res;

        # optim: skip detecting columns we're not showing
        next unless $col ~~ $self->{_draw}{fcols};

        # but detect from all rows, not just ones we're showing
        my $type = $self->get_column_style($col, 'type');
        my $subtype;
      DETECT:
        {
            last DETECT if $type;
            if ($col =~ /\?/) {
                $type = 'bool';
                last DETECT;
            }

            require Parse::VarName;
            my @words = map {lc} @{ Parse::VarName::split_varname_words(
                varname=>$col) };
            for (qw/date time ctime mtime utime atime stime/) {
                if ($_ ~~ @words) {
                    $type = 'date';
                    last DETECT;
                }
            }

            my $pass = 1;
            for my $j (0..@$rows) {
                my $v = $rows->[$j][$i];
                next unless defined($v);
                do { $pass=0; last } unless looks_like_number($v);
            }
            if ($pass) {
                $type = 'num';
                if ($col =~ /(pct|percent(?:age))\b|\%/) {
                    $subtype = 'pct';
                }
                last DETECT;
            }
            $type = 'str';
        } # DETECT

        $res->{type} = $type;
        if ($type eq 'bool') {
            $res->{align}   = 'center';
            $res->{valign}  = 'center';
            $res->{fgcolor} = $ct->{colors}{bool_data};
            $res->{formats} = [[bool => {style => $self->{use_utf8} ?
                                             "check_cross" : "Y_N"}]];
        } elsif ($type eq 'date') {
            $res->{align}   = 'middle';
            $res->{fgcolor} = $ct->{colors}{date_data};
            $res->{formats} = [['date' => {}]];
        } elsif ($type eq 'num') {
            $res->{align}   = 'right';
            $res->{fgcolor} = $ct->{colors}{num_data};
            if (($subtype//"") eq 'pct') {
                $res->{formats} = [[num => {style=>'percent'}]];
            }
        } else {
            $res->{fgcolor} = $ct->{colors}{str_data};
            $res->{wrap}    = 1;
        }
    }

    #use Data::Dump; dd $fcol_detect;
    $fcol_detect;
}

sub _read_style_envs {
    my $self = shift;

    next if $self->{_draw}{read_style_envs}++;

    if ($ENV{ANSITABLE_COLUMN_STYLES}) {
        require JSON;
        my $ss = JSON::decode_json($ENV{ANSITABLE_COLUMN_STYLES});
        for my $col (keys %$ss) {
            my $ci = $self->_colnum($col);
            my $s = $ss->{$col};
            for my $k (keys %$s) {
                my $v = $s->{$k};
            die "Unknown column style '$k' (for column $col) in ".
                "ANSITABLE_COLUMN_STYLES environment, ".
                    "please use one of [".join(", ", @$COLUMN_STYLES)."]"
                        unless $k ~~ $COLUMN_STYLES;
                $self->{_column_styles}[$ci]{$k} //= $v;
            }
        }
    }

    if ($ENV{ANSITABLE_ROW_STYLES}) {
        require JSON;
        my $ss = JSON::decode_json($ENV{ANSITABLE_ROW_STYLES});
        for my $row (keys %$ss) {
            my $s = $ss->{$row};
            for my $k (keys %$s) {
                my $v = $s->{$k};
            die "Unknown row style '$k' (for row $row) in ".
                "ANSITABLE_ROW_STYLES environment, ".
                    "please use one of [".join(", ", @$ROW_STYLES)."]"
                        unless $k ~~ $ROW_STYLES;
                $self->{_row_styles}[$row]{$k} //= $v;
            }
        }
    }

    if ($ENV{ANSITABLE_CELL_STYLES}) {
        require JSON;
        my $ss = JSON::decode_json($ENV{ANSITABLE_CELL_STYLES});
        for my $cell (keys %$ss) {
            die "Invalid cell specification in ANSITABLE_CELL_STYLES: ".
                "$cell, please use 'row,col'"
                    unless $cell =~ /^(.+),(.+)$/;
            my $row = $1;
            my $col = $2;
            my $ci = $self->_colnum($col);
            my $s = $ss->{$cell};
            for my $k (keys %$s) {
                my $v = $s->{$k};
            die "Unknown cell style '$k' (for row $row) in ".
                "ANSITABLE_CELL_STYLES environment, ".
                    "please use one of [".join(", ", @$CELL_STYLES)."]"
                        unless $k ~~ $CELL_STYLES;
                $self->{_cell_styles}[$row][$ci]{$k} //= $v;
            }
        }
    }
}

# calculate width and height of a cell, but skip calculating (to save some
# cycles) if width is already set by frow_setheights / fcol_setwidths.
sub _opt_calc_width_height {
    my ($self, $frow_num, $col, $text) = @_;

    $col = $self->_colnum($col);
    my $setw  = $self->{_draw}{fcol_setwidths}[$col];
    my $calcw = !defined($setw) || $setw < 0;
    my $seth  = defined($frow_num) ?
        $self->{_draw}{frow_setheights}[$frow_num] : undef;
    my $calch = !defined($seth) || $seth < 0;

    my $wh;
    if ($calcw) {
        $wh = ta_mbswidth_height($text);
        $wh->[0] = -$setw if defined($setw) && $setw<0 && $wh->[0] < -$setw;
        $wh->[1] = $seth if !$calch;
        $wh->[1] = -$seth if defined($seth) && $seth<0 && $wh->[1] < -$seth;
    } elsif ($calch) {
        my $h = 1; $h++ while $text =~ /\n/go;
        $h = -$seth if defined($seth) && $seth<0 && $h < -$seth;
        $wh = [$setw, $h];
    } else {
        $wh = [$setw, $seth];
    }
    $wh;
}

sub _apply_column_formats {
    my $self = shift;

    my $cols  = $self->{columns};
    my $frows = $self->{_draw}{frows};
    my $fcols = $self->{_draw}{fcols};
    my $fcol_detect = $self->{_draw}{fcol_detect};

    my %seen;
    for my $i (0..@$cols-1) {
        next unless $cols->[$i] ~~ $fcols;
        next if $seen{$cols->[$i]}++;
        my @fmts = @{ $self->get_column_style($i, 'formats') //
                          $fcol_detect->[$i]{formats} // [] };
        if (@fmts) {
            require Data::Unixish::Apply;
            my $res = Data::Unixish::Apply::apply(
                in => [map {$frows->[$_][$i]} 0..@$frows-1],
                functions => \@fmts,
            );
            die "Can't format column $cols->[$i]: $res->[0] - $res->[1]"
                unless $res->[0] == 200;
            $res = $res->[2];
            for (0..@$frows-1) { $frows->[$_][$i] = $res->[$_] // "" }
        } else {
            # change null to ''
            for (0..@$frows-1) { $frows->[$_][$i] //= "" }
        }
    }
}

sub _apply_cell_formats {
    my $self = shift;

    my $cols  = $self->{columns};
    my $rows  = $self->{rows};
    my $fcols = $self->{_draw}{fcols};
    my $frows = $self->{_draw}{frows};
    my $frow_orig_indices = $self->{_draw}{frow_orig_indices};

    for my $i (0..@$frows-1) {
        my %seen;
        my $origi = $frow_orig_indices->[$i];
        for my $j (0..@$cols-1) {
            next unless $cols->[$j] ~~ $fcols;
            next if $seen{$cols->[$j]}++;

            my $fmts = $self->get_cell_style($i, $j, 'formats');
            if (defined $fmts) {
                require Data::Unixish::Apply;
                my $res = Data::Unixish::Apply::apply(
                    in => [ $rows->[$origi][$j] ],
                    functions => $fmts,
                );
                die "Can't format cell ($origi, $cols->[$j]): ".
                    "$res->[0] - $res->[1]" unless $res->[0] == 200;
                $frows->[$i][$j] = $res->[2][0] // "";
            }
        } # col
    }
}

sub _calc_row_widths_heights {
    my $self = shift;

    my $cols  = $self->{columns};
    my $fcols = $self->{_draw}{fcols};
    my $frows = $self->{_draw}{frows};

    my $frow_heights = $self->{_draw}{frow_heights};
    my $fcol_widths  = $self->{_draw}{fcol_widths};
    my $frow_orig_indices = $self->{_draw}{frow_orig_indices};

    my $height = $self->{cell_height};
    my $tpad = $self->{cell_tpad} // $self->{cell_vpad}; # tbl-lvl tpad
    my $bpad = $self->{cell_bpad} // $self->{cell_vpad}; # tbl-lvl bpad
    my $cswidths = [map {$self->get_column_style($_, 'width')} 0..@$cols-1];
    for my $i (0..@$frows-1) {
        my %seen;
        my $origi = $frow_orig_indices->[$i];
        my $rsheight = $self->get_row_style($origi, 'height');
        for my $j (0..@$cols-1) {
            next unless $cols->[$j] ~~ $fcols;
            next if $seen{$cols->[$j]}++;

            my $wh = $self->_opt_calc_width_height($i,$j, $frows->[$i][$j]);

            $fcol_widths->[$j]  = $wh->[0] if $fcol_widths->[$j] < $wh->[0];
            $frow_heights->[$i] = $wh->[1] if !defined($frow_heights->[$i])
                || $frow_heights->[$i] < $wh->[1];
        } # col
    }
}

sub _calc_table_width_height {
    my $self = shift;

    my $cols  = $self->{columns};
    my $fcols = $self->{_draw}{fcols};
    my $frows = $self->{_draw}{frows};
    my $fcol_widths  = $self->{_draw}{fcol_widths};
    my $fcol_lpads   = $self->{_draw}{fcol_lpads};
    my $fcol_rpads   = $self->{_draw}{fcol_rpads};
    my $frow_tpads   = $self->{_draw}{frow_tpads};
    my $frow_bpads   = $self->{_draw}{frow_bpads};
    my $frow_heights = $self->{_draw}{frow_heights};

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
        $self->{cell_tpad} // $self->{cell_vpad};
    $h += $self->{_draw}{header_height};
    $h += $self->{header_bpad} // $self->{header_vpad} //
        $self->{cell_bpad} // $self->{cell_vpad};
    $h += 1 if length($self->get_border_char(2, 0));
    for my $i (0..@$frows-1) {
        $h += $frow_tpads->[$i] + $frow_heights->[$i] + $frow_bpads->[$i];
        $h += 1 if $self->_should_draw_row_separator($i);
    }
    $h += 1 if length($self->get_border_char(5, 0));
    $self->{_draw}{table_height}  = $h;
}

# if there are text columns with no width set, and the column width is wider
# than terminal, try to adjust widths so it fit into the terminal, if possible.
# return 1 if widths (fcol_widths) adjusted.
sub _adjust_column_widths {
    my $self = shift;

    # try to find wrappable columns that do not have their widths set. currently
    # the algorithm is not proper, it just targets columns which are wider than
    # a hard-coded value (30). it should take into account the longest word in
    # the content/header, but this will require another pass at the text to
    # analyze it.

    my $fcols = $self->{_draw}{fcols};
    my $frows = $self->{_draw}{frows};
    my $fcol_setwidths = $self->{_draw}{fcol_setwidths};
    my $fcol_detect    = $self->{_draw}{fcol_detect};
    my $fcol_widths    = $self->{_draw}{fcol_widths};
    my %acols;
    my %origw;
    for my $i (0..@$fcols-1) {
        my $ci = $self->_colnum($fcols->[$i]);
        next if defined($fcol_setwidths->[$ci]) && $fcol_setwidths->[$ci]>0;
        next if $fcol_widths->[$ci] < 30;
        next unless $self->get_column_style($ci, 'wrap') //
            $self->{column_wrap} // $fcol_detect->[$ci]{wrap};
        $acols{$ci}++;
        $origw{$ci} = $fcol_widths->[$ci];
    }
    return 0 unless %acols;

    # only do this if table width exceeds terminal width
    require Term::Size;
    my ($termw, $termh) = Term::Size::chars();
    return 0 unless $termw;
    my $excess = $self->{_draw}{table_width} - $termw;
    return 0 unless $excess > 0;

    # reduce text columns proportionally
    my $w = 0; # total width of all to-be-adjusted columns
    $w += $fcol_widths->[$_] for keys %acols;
    return 0 unless $w > 0;
    my $reduced = 0;
  REDUCE:
    while (1) {
        my $has_reduced;
        for my $ci (keys %acols) {
            last REDUCE if $reduced >= $excess;
            if ($fcol_widths->[$ci] > 30) {
                $fcol_widths->[$ci]--;
                $reduced++;
                $has_reduced++;
            }
        }
        last if !$has_reduced;
    }

    # reset widths
    for my $ci (keys %acols) {
        $fcol_setwidths->[$ci] = $fcol_widths->[$ci];
        $fcol_widths->[$ci] = 0; # reset
    }

    # wrap and set setwidths so it doesn't grow again during recalculate
    for my $ci (keys %acols) {
        next unless $origw{$ci} != $fcol_widths->[$ci];
        for (0..@$frows-1) {
            $frows->[$_][$ci] = ta_mbwrap(
                $frows->[$_][$ci], $fcol_setwidths->[$ci]);
        }
    }

    # recalculate column widths
    $self->_calc_row_widths_heights;
    $self->_calc_table_width_height;

    1;
}

# filter columns & rows, calculate widths/paddings, format data, put the results
# in _draw (draw data) attribute.
sub _prepare_draw {
    my $self = shift;

    $self->{_draw} = {};
    $self->{_draw}{y} = 0; # current line
    $self->{_draw}{buf} = [];

    $self->_read_style_envs;

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
        $fcols = [grep {defined} map {looks_like_number($_) ?
                                          $cols->[$_] : $_} @$cf];
    } else {
        $fcols = $cols;
    }

    my $fcol_setwidths  = []; # index = [colnum], from cell_width/col width
    my $frow_setheights = []; # index = [frownum], from cell_height/row height
    $self->{_draw}{fcol_setwidths}  = $fcol_setwidths;
    $self->{_draw}{frow_setheights} = $frow_setheights;

    # calculate widths/heights of header, store width settings, column [lr]pads
    my $fcol_widths = []; # index = [colnum]
    my $header_height;
    my $fcol_lpads  = []; # index = [colnum]
    my $fcol_rpads  = []; # ditto
    {
        my %seen;
        my $lpad = $self->{cell_lpad} // $self->{cell_pad}; # tbl-lvl leftp
        my $rpad = $self->{cell_rpad} // $self->{cell_pad}; # tbl-lvl rightp
        for my $i (0..@$cols-1) {
            next unless $cols->[$i] ~~ $fcols;
            next if $seen{$cols->[$i]}++;
            $fcol_setwidths->[$i] = $self->get_column_style($i, 'width') //
                $self->{cell_width};
            my $wh = $self->_opt_calc_width_height(undef, $i, $cols->[$i]);
            $fcol_widths->[$i] = $wh->[0];
            $header_height = $wh->[1]
                if !defined($header_height) || $header_height < $wh->[1];
            $fcol_lpads->[$i] = $self->get_column_style($i, 'lpad') //
                $self->get_column_style($i, 'pad') // $lpad;
            $fcol_rpads->[$i] = $self->get_column_style($i, 'rpad') //
                $self->get_column_style($i, 'pad') // $rpad;
        }
    }
    $self->{_draw}{header_height} = $header_height;
    $self->{_draw}{fcol_lpads}  = $fcol_lpads;
    $self->{_draw}{fcol_rpads}  = $fcol_rpads;

    # calculate vertical paddings of data rows, store height settings
    my $frow_tpads  = []; # index = [frownum]
    my $frow_bpads  = []; # ditto
    my $frows = [];
    my $frow_separators = [];
    my $frow_orig_indices = []; # needed when accessing original row data
    {
        my $tpad = $self->{cell_tpad} // $self->{cell_vpad}; # tbl-lvl top pad
        my $bpad = $self->{cell_bpad} // $self->{cell_vpad}; # tbl-lvl botom pad
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
            push @$frow_setheights, $self->get_row_style($i, 'height') //
                $self->{cell_height};
            push @$frows, [@$row]; # 1-level clone, for storing formatted values
            push @$frow_separators, $j if $i ~~ $self->{_row_separators};
            push @$frow_tpads, $self->get_row_style($i, 'tpad') //
                $self->get_row_style($i, 'vpad') // $tpad;
            push @$frow_bpads, $self->get_row_style($i, 'bpad') //
                $self->get_row_style($i, 'vpad') // $bpad;
            push @$frow_orig_indices, $i;
        }
    }
    $self->{_draw}{fcols}             = $fcols;
    $self->{_draw}{frows}             = $frows;
    $self->{_draw}{frow_separators}   = $frow_separators;
    $self->{_draw}{frow_tpads}        = $frow_tpads;
    $self->{_draw}{frow_bpads}        = $frow_bpads;
    $self->{_draw}{frow_orig_indices} = $frow_orig_indices;

    # detect column type from data/header name. assign default column align,
    # valign, fgcolor, bgcolor, formats.
    my $fcol_detect = $self->_detect_column_types;
    $self->{_draw}{fcol_detect} = $fcol_detect;

    # apply column formats
    $self->_apply_column_formats;

    # calculate row widths/heights
    $self->{_draw}{frow_heights}  = [];
    $self->{_draw}{fcol_widths}   = $fcol_widths;
    $self->_calc_row_widths_heights;

    # wrap wrappable columns
    {
        my %seen;
        for my $i (0..@$cols-1) {
            next unless $cols->[$i] ~~ $fcols;
            next if $seen{$cols->[$i]}++;
            if (($self->get_column_style($i, 'wrap') // $self->{column_wrap} //
                 $fcol_detect->[$i]{wrap}) &&
                     defined($fcol_setwidths->[$i]) &&
                         $fcol_setwidths->[$i]>0) {
                for (0..@$frows-1) {
                    $frows->[$_][$i] = ta_mbwrap(
                        $frows->[$_][$i], $fcol_setwidths->[$i]);
                }
            }
        }
    }

    # apply cell formats
    $self->_apply_cell_formats;

    # apply cell formats, calculate widths/heights of data rows
    my $frow_heights  = []; # index = [frownum]
    {
        my $height = $self->{cell_height};
        my $tpad = $self->{cell_tpad} // $self->{cell_vpad}; # tbl-lvl tpad
        my $bpad = $self->{cell_bpad} // $self->{cell_vpad}; # tbl-lvl bpad
        my $cswidths = [map {$self->get_column_style($_, 'width')} 0..@$cols-1];
        for my $i (0..@$frows-1) {
            my %seen;
            my $origi = $frow_orig_indices->[$i];
            my $rsheight = $self->get_row_style($origi, 'height');
            for my $j (0..@$cols-1) {
                next unless $cols->[$j] ~~ $fcols;
                next if $seen{$cols->[$j]}++;

                # apply cell-level formats
                my $fmts = $self->get_cell_style($i, $j, 'formats');
                if (defined $fmts) {
                    require Data::Unixish::Apply;
                    my $res = Data::Unixish::Apply::apply(
                        in => [ $rows->[$origi][$j] ],
                        functions => $fmts,
                    );
                    die "Can't format cell ($origi, $cols->[$j]): ".
                        "$res->[0] - $res->[1]" unless $res->[0] == 200;
                    $frows->[$i][$j] = $res->[2][0] // "";
                }

                # calculate heights/widths of data
                my $wh = $self->_opt_calc_width_height($i,$j, $frows->[$i][$j]);

                $fcol_widths->[$j]  = $wh->[0] if $fcol_widths->[$j] < $wh->[0];
                $frow_heights->[$i] = $wh->[1] if !defined($frow_heights->[$i])
                    || $frow_heights->[$i] < $wh->[1];

            } # col
        }
    }
    $self->{_draw}{frow_heights}  = $frow_heights;
    $self->{_draw}{fcol_widths}   = $fcol_widths;

    # calculate table width and height
    $self->_calc_table_width_height;

    # try to adjust widths if possible (if table is too wide)
    $self->_adjust_column_widths;
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

    $args //= {};
    if (ref($c) eq 'CODE') {
        $c = $c->($self, %$args);
    }

    # empty or already ansi? skip
    return '' if !defined($c) || !length($c);
    return $c if index($c, "\e[") >= 0;

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

# apply align/valign, apply padding, apply default fgcolor/bgcolor to text,
# truncate to specified cell's width & height
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

    for (@lines) {
        $_ = (" "x$lpad) . ta_mbpad($_, $width, $pad, " ", 1) . (" "x$rpad);
        # add default color
        s/\e\[0m(?=.)/\e[0m$color/g if length($color);
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
    #} elsif (defined $self->{_draw}{fcol_detect}[$i]{fgcolor}) {
    #    $fgcolor = $self->color2ansi($self->{_draw}{fcol_detect}[$i]{fgcolor});
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

    my $align =
        $self->{header_align} //
            $self->{cell_align} //
                $self->{_draw}{fcol_detect}[$i]{align} //
                    'left';
    my $valign =
        $self->{header_valign} //
            $self->{cell_valign} //
                $self->{_draw}{fcol_detect}[$i]{valign} //
                    'top';

    my $lpad = $self->{_draw}{fcol_lpads}[$i];
    my $rpad = $self->{_draw}{fcol_rpads}[$i];
    my $tpad = $self->{header_tpad} // $self->{header_vpad} // 0;
    my $bpad = $self->{header_bpad} // $self->{header_vpad} // 0;

    #use Data::Dump; print "header cell: "; dd {i=>$i, col=>$self->{columns}[$i], fgcolor=>$fgcolor, bgcolor=>$bgcolor};
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

    my $ct   = $self->{color_theme};
    my $oy   = $self->{_draw}{frow_orig_indices}[$y];
    my $cell = $self->{_draw}{frows}[$y][$x];
    my $args = {row_num=>$y, col_num=>$x, data=>$cell,
                orig_data=>$self->{rows}[$oy][$x]};

    my $tmp;
    my $fgcolor;
    if (defined ($tmp = $self->get_cell_style($oy, $x, 'fgcolor'))) {
        $fgcolor = $self->color2ansi($tmp, $args);
    } elsif (defined ($tmp = $self->get_row_style($oy, 'fgcolor'))) {
        $fgcolor = $self->color2ansi($tmp, $args);
    } elsif (defined ($tmp = $self->get_column_style($x, 'fgcolor'))) {
        $fgcolor = $self->color2ansi($tmp, $args);
    } elsif (defined ($tmp = $self->{cell_fgcolor})) {
        $fgcolor = $self->color2ansi($tmp, $args);
    } elsif (defined ($tmp = $self->{_draw}{fcol_detect}[$x]{fgcolor})) {
        $fgcolor = $self->color2ansi($tmp, $args);
    } elsif (defined $ct->{colors}{cell}) {
        $fgcolor = $self->get_theme_color('cell', $args);
    } else {
        $fgcolor = "";
    }

    my $bgcolor;
    if (defined ($tmp = $self->get_cell_style($oy, $x, 'bgcolor'))) {
        $bgcolor = $self->color2ansi($tmp, $args, 1);
    } elsif (defined ($tmp = $self->get_row_style($oy, 'bgcolor'))) {
        $bgcolor = $self->color2ansi($tmp, $args, 1);
    } elsif (defined ($tmp = $self->get_column_style($x, 'bgcolor'))) {
        $bgcolor = $self->color2ansi($tmp, $args, 1);
    } elsif (defined ($tmp = $self->{cell_bgcolor})) {
        $bgcolor = $self->color2ansi($tmp, $args, 1);
    } elsif (defined ($tmp = $self->{_draw}{fcol_detect}[$x]{bgcolor})) {
        $bgcolor = $self->color2ansi($tmp, $args, 1);
    } elsif (defined $ct->{colors}{cell_bg}) {
        $bgcolor = $self->get_theme_color('cell_bg', $args);
    } else {
        $bgcolor = "";
    }

    my $align =
        $self->get_cell_style($y, $x, 'align') //
            $self->get_row_style($y, 'align') //
                $self->get_column_style($x, 'align') //
                    $self->{cell_align} //
                        $self->{_draw}{fcol_detect}[$x]{align} //
                            'left';
    my $valign =
        $self->get_cell_style($y, $x, 'valign') //
            $self->get_row_style($y, 'valign') //
                $self->get_column_style($x, 'valign') //
                    $self->{cell_valign} //
                        $self->{_draw}{fcol_detect}[$x]{valign} //
                            'top';
    #say "D:y=$y, x=$x, align=$align, valign=$valign";

    my $lpad = $self->{_draw}{fcol_lpads}[$x];
    my $rpad = $self->{_draw}{fcol_rpads}[$x];
    my $tpad = $self->{_draw}{frow_tpads}[$y];
    my $bpad = $self->{_draw}{frow_bpads}[$y];

    #say "D:oy=$oy, y=$y, x=$x, fgcolor=$fgcolor, bgcolor=$bgcolor";
    $self->_get_cell_lines(
        $cell,                            # text
        $self->{_draw}{fcol_widths}[$x],  # width
        $self->{_draw}{frow_heights}[$y], # height
        $align, $valign,                  # aligns
        $lpad, $rpad, $tpad, $bpad,       # paddings
        $fgcolor . $bgcolor);
}

sub draw {
    my ($self) = @_;

    $self->_prepare_draw;

    my $cols  = $self->{columns};
    my $fcols = $self->{_draw}{fcols};
    my $frows = $self->{_draw}{frows};
    my $frow_heights    = $self->{_draw}{frow_heights};
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
            my $ci = $self->_colnum($fcols->[$i]);
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
            my $ci = $self->_colnum($fcols->[$i]);
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
            my $ci = $self->_colnum($fcols->[$i]);
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
                my $ci = $self->_colnum($fcols->[$i]);
                if (defined($seen{$i})) {
                    $dcell_lines->[$i] = $dcell_lines->[$seen{$i}];
                }
                $seen{$i} = $ci;
                $dcell_lines->[$i] = $self->_get_data_cell_lines($r, $ci);
            }

            if (@$fcols) {
                for my $l (0..@{ $dcell_lines->[0] }-1) {
                    $self->draw_border_char({row_num=>$r}, 3, 0);
                    for my $i (0..@$fcols-1) {
                        $self->draw_str($dcell_lines->[$i][$l]);
                        $self->draw_color_reset;
                        $self->draw_border_char({row_num=>$r},
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
                    my $ci = $self->_colnum($fcols->[$i]);
                    push @b, 4, 1,
                        $fcol_lpads->[$ci] + $fcol_widths->[$ci] +
                            $fcol_rpads->[$ci];
                    push @b, 4, $i==@$fcols-1 ? 3:2, 1;
                }
                $self->draw_border_char({row_num=>$r}, @b);
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
            my $ci = $self->_colnum($fcols->[$i]);
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

=for Pod::Coverage ^(BUILD|draw_.+|color2ansi|get_color_reset|get_theme_color|get_border_char)$

=head1 SYNOPSIS

 use 5.010;
 use Text::ANSITable;

 # don't forget this if you want to output utf8 characters
 binmode(STDOUT, ":utf8");

 my $t = Text::ANSITable->new;

 # set styles
 $t->border_style('Default::bold');  # if not, a nice default is picked
 $t->color_theme('Default::sepia');  # if not, a nice default is picked

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
B<ansitable-list-border-styles> script. Or, you can also view the documentation
for the C<Text::ANSITable::BorderStyle::*> modules, where border styles are
searched.

To choose border style, either set the C<border_style> attribute to an available
border style or a border specification directly.

 $t->border_style("Default::singleh_boxchar");
 $t->border_style("Foo::bar");   # dies, no such border style
 $t->border_style({ ... }); # set specification directly

If no border style is selected explicitly, a nice default will be chosen. You
can also set the C<ANSITABLE_BORDER_STYLE> environment variable to set the
default.

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

Or you can also run the provided B<ansitable-list-color-themes> script. Or you
can view the documentation for the C<Text::ANSITable::ColorTheme::*> modules
where color themes are searched.

To choose a color theme, either set the C<color_theme> attribute to an available
color theme or a border specification directly.

 $t->color_theme("Default::default_nogradation");
 $t->color_theme("Foo::bar");    # dies, no such color theme
 $t->color_theme({ ... });  # set specification directly

If no color theme is selected explicitly, a nice default will be chosen. You can
also set the C<ANSITABLE_COLOR_THEME> environment variable to set the default.

To create a new color theme, create a module under
C<Text::ANSITable::ColorTheme::>. Please see one of the existing color theme
modules for example, like L<Text::ANSITable::ColorTheme::Default>. Color for
items must be specified as 6-hexdigit RGB value (like C<ff0088>) or ANSI escape
codes (e.g. C<"\e[31;1m"> for bold red foregound color, or C<"\e[48;5;226m"> for
lemon yellow background color). You can also return a 2-element array containing
RGB value for foreground and background, respectively.

For flexibility, color can also be a coderef which should produce a color value.
This allows you to do, e.g. gradation border color, random color, etc (see
L<Text::ANSITable::ColorTheme::Demo>). Code will be called with C<< ($self,
%args) >> where C<%args> contains various information, like C<name> (the item
name being requested). You can get the row position from C<< $self->{_draw}{y}
>>.


=head1 COLUMN WIDTHS

By default column width is set just so it is enough to show the widest data.
This can be customized in the following ways (in order of precedence, from
lowest):

=over

=item * table-level C<cell_width> attribute

This sets width for all columns.

=item * per-column C<width> style

 $t->set_column_style('colname', width => 20);

=back

You can use negative number to mean I<minimum> width.


=head1 ROW HEIGHTS

This can be customized in the following ways (in order of precedence, from
lowest):

=over

=item * table-level C<cell_height> attribute

This sets height for all rows.

=item * per-row C<height> style

 $t->set_row_style(1, height => 2);

=back

You can use negative number to mean I<minimum> height.


=head1 CELL (HORIZONTAL) PADDING

By default cell (horizontal) padding is 1. This can be customized in the
following ways (in order of precedence, from lowest):

=over

=item * table-level C<cell_pad> attribute

This sets left and right padding for all columns.

=item * table-level C<cell_lpad> and C<cell_rpad> attributes

They set left and right padding for all columns, respectively.

=item * per-column C<pad> style

 $t->set_column_style($colname, pad => 0);

=item * per-column C<lpad>/C<rpad> style

 $t->set_column_style($colname, lpad => 1);
 $t->set_column_style($colname, rpad => 2);

=back


=head1 ROW VERTICAL PADDING

Default vertical padding is 0. This can be changed in the following ways (in
order of precedence, from lowest):

=over

=item * table-level C<row_vpad> attribute

This sets top and bottom padding for all rows.

=item * table-level C<row_tpad>/C<row_bpad> attributes

They set top/bottom padding separately for all rows.

=item * per-row C<vpad> style

Example:

 $t->set_row_style($rownum, vpad => 1);

When adding row:

 $t->add_row($rownum, {vpad=>1});

=item * per-row C<tpad>/C<vpad> style

Example:

 $t->set_row_style($row_num, tpad => 1);
 $t->set_row_style($row_num, bpad => 2);

When adding row:

 $t->add_row($row, {tpad=>1, bpad=>2});

=back


=head1 CELL COLORS

By default data format colors are used, e.g. cyan/green for text (using the
default color scheme, items C<num_data>, C<bool_data>, etc). In absense of that,
C<cell_fgcolor> and C<cell_bgcolor> from the color scheme are used. You can
customize colors in the following ways (ordered by precedence, from lowest):

=over

=item * table-level C<cell_fgcolor> and C<cell_bgcolor> attributes

Sets all cells' colors. Color should be specified using 6-hexdigit RGB which
will be converted to the appropriate terminal color.

Can also be set to a coderef which will receive ($rownum, $colname) and should
return an RGB color.

=item * per-column C<fgcolor> and C<bgcolor> styles

Example:

 $t->set_column_style('colname', fgcolor => 'fa8888');
 $t->set_column_style('colname', bgcolor => '202020');

=item * per-row F<fgcolor> and B<bgcolor> styles

Example:

 $t->set_row_style($rownum, {fgcolor => 'fa8888', bgcolor => '202020'});

When adding row/rows:

 $t->add_row($row, {fgcolor=>..., bgcolor=>...});
 $t->add_rows($rows, {bgcolor=>...});

=item * per-cell F<fgcolor> and B<bgcolor> styles

Example:

 $t->set_cell_style($rownum, $colname, fgcolor => 'fa8888');
 $t->set_cell_style($rownum, $colname, bgcolor => '202020');

=back

For flexibility, all colors can be specified as coderef. See L</"COLOR THEMES">
for more details.


=head1 CELL (HORIZONTAL AND VERTICAL) ALIGNMENT

By default, numbers are right-aligned, dates and bools are centered, and the
other data types (text including) are left-aligned. All data are top-valigned.
This can be customized in the following ways (in order of precedence, from
lowest):

=over

=item * table-level C<cell_align> and C<cell_valign> attribute

=item * per-column C<align> and C<valign> styles

Example:

 $t->set_column_style($colname, align  => 'middle'); # or left, or right
 $t->set_column_style($colname, valign => 'top');    # or bottom, or middle

=item * per-row C<align> and C<valign> styles

=item * per-cell C<align> and C<valign> styles

 $t->set_cell_style($rownum, $colname, align  => 'middle');
 $t->set_cell_style($rownum, $colname, valign => 'top');

=back


=head1 CELL FORMATS

The per-column and per-cell C<formats> styles regulate how to format data. The
value for this style setting will be passed to L<Data::Unixish::Apply>'s
C<apply()>, as the C<functions> argument. So it should be a single string (like
C<date>) or an array (like C<< ['date', ['centerpad', {width=>20}]] >>).

See L<Data::Unixish> or install L<App::dux> and then run C<dux -l> to see what
functions are available. Functions of interest to formatting data include:
C<bool>, C<num>, C<sprintf>, C<sprintfn>, C<wrap>, (among others).


=head1 ATTRIBUTES

=head2 columns => ARRAY OF STR

Store column names. Note that when drawing, you can omit some columns, reorder
them, or display some more than once (see C<column_filter> attribute).

=head2 rows => ARRAY OF ARRAY OF STR

Store row data. You can set this attribute directly, or add rows incrementally
using C<add_row()> and C<add_rows()> methods.

=head2 row_filter => CODE|ARRAY OF INT

When drawing, only show rows that match this. Can be an array containing indices
of rows which should be shown, or a coderef which will be called for each row
with arguments C<< ($row, $row_num) >> and should return a bool value indicating
whether that row should be displayed.

Internal note: During drawing, rows will be filtered and put into C<<
$t->{_draw}{frows} >>.

=head2 column_filter => CODE|ARRAY OF STR

When drawing, only show columns that match this. Can be an array containing
names of columns that should be displayed (column names can be in different
order or duplicate, column can also be referred to with its numeric index). Can
also be a coderef which will be called with C<< ($col_name, $col_num) >> for
every column and should return a bool value indicating whether that column
should be displayed. The coderef version is more limited in that it cannot
reorder the columns or instruct for the same column to be displayed more than
once.

Internal note: During drawing, column names will be filtered and put into C<<
$t->{_draw}{fcols} >>.

=head2 column_wrap => BOOL

Set column wrapping for all columns. Can be overriden by per-column C<wrap>
style. By default column wrapping will only be done for text columns and when
width is explicitly set to a positive value.

=head2 use_color => BOOL

Whether to output color. Default is taken from C<COLOR> environment variable, or
detected via C<(-t STDOUT)>. If C<use_color> is set to 0, an attempt to use a
colored color theme (i.e. anything that is not the C<no_color> theme) will
result in an exception.

(In the future, setting C<use_color> to 0 might opt the module to use
normal/plain string routines instead of the slower ta_* functions from
L<Text::ANSI::Util>; this also means that the module won't handle ANSI escape
codes in the content text.)

=head2 color_depth => INT

Terminal's color depth. Either 16, 256, or 2**24 (16777216). Default will be
retrieved from C<COLOR_DEPTH> environment or detected using L<Term::Detect>.

=head2 use_box_chars => BOOL

Whether to use box drawing characters. Drawing box drawing characters can be
problematic in some places because it uses ANSI escape codes to switch to (and
back from) line drawing mode (C<"\e(0"> and C<"\e(B">, respectively).

Default is taken from C<BOX_CHARS> environment variable, or 1. If
C<use_box_chars> is set to 0, an attempt to use a border style that uses box
drawing chararacters will result in an exception.

=head2 use_utf8 => BOOL

Whether to use Unicode (UTF8) characters. Default is taken from C<UTF8>
environment variable, or detected using L<Term::Detect>, or guessed via L<LANG>
environment variable. If C<use_utf8> is set to 0, an attempt to select a border
style that uses Unicode characters will result in an exception.

(In the future, setting C<use_utf8> to 0 might opt the module to use the
non-"mb_*" version of functions from L<Text::ANSI::Util>, e.g. C<ta_wrap()>
instead of C<ta_mbwrap()>, and so on).

=head2 border_style => HASH

Border style specification to use.

You can set this attribute's value with a specification or border style name.
See L<"/BORDER STYLES"> for more details.

=head2 border_style_args => HASH

Some border styles can accept arguments. You can set it here. See the
corresponding border style's documentation for information on what arguments it
accepts.

=head2 color_theme => HASH

Color theme specification to use.

You can set this attribute's value with a specification or color theme name. See
L<"/COLOR THEMES"> for more details.

=head2 color_theme_args => HASH

Some color themes can accept arguments. You can set it here. See the
corresponding color theme's documentation for information on what arguments it
accepts.

=head2 show_header => BOOL (default: 1)

When drawing, whether to show header.

=head2 show_row_separator => INT (default: 2)

When drawing, whether to show separator lines between rows. The default (2) is
to only show separators drawn using C<add_row_separator()>. If you set this to
1, lines will be drawn after every data row. If you set this attribute to 0, no
lines will be drawn whatsoever.

=head2 cell_width => INT

Set width for all cells. Can be overriden by per-column C<width> style.

=head2 cell_height => INT

Set height for all cell. Can be overriden by per-row C<height> style.

=head2 cell_align => STR

Set (horizontal) alignment for all cells. Either C<left>, C<middle>, or
C<right>. Can be overriden by per-column/per-row/per-cell C<align> style.

=head2 cell_valign => STR

Set (horizontal) alignment for all cells. Either C<top>, C<middle>, or
C<bottom>. Can be overriden by per-column/per-row/per-cell C<align> style.

=head2 cell_pad => INT

Set (horizontal) padding for all cells. Can be overriden by per-column C<pad>
style.

=head2 cell_lpad => INT

Set left padding for all cells. Overrides the C<cell_pad> attribute. Can be
overriden by per-column C<lpad> style.

=head2 cell_rpad => INT

Set right padding for all cells. Overrides the C<cell_pad> attribute. Can be
overriden by per-column C<rpad> style.

=head2 cell_vpad => INT

Set vertical padding for all cells. Can be overriden by per-row C<vpad> style.

=head2 cell_tpad => INT

Set top padding for all cells. Overrides the C<cell_vpad> attribute. Can be
overriden by per-row C<tpad> style.

=head2 cell_bpad => INT

Set bottom padding for all cells. Overrides the C<cell_vpad> attribute. Can be
overriden by per-row C<bpad> style.

=head2 cell_fgcolor => RGB|CODE

Set foreground color for all cells. Value should be 6-hexdigit RGB. Can also be
a coderef that will receive %args (e.g. row_num, col_name, col_num) and should
return an RGB color. Can be overriden by per-cell C<fgcolor> style.

=head2 cell_bgcolor => RGB|CODE

Like C<cell_fgcolor> but for background color.

=head2 header_fgcolor => RGB|CODE

Set foreground color for all headers. Overrides C<cell_fgcolor> for headers.
Value should be a 6-hexdigit RGB. Can also be a coderef that will receive %args
(e.g. col_name, col_num) and should return an RGB color.

=head2 header_bgcolor => RGB|CODE

Like C<header_fgcolor> but for background color.

=head2 header_align => STR

=head2 header_valign => STR

=head2 header_vpad => INT

=head2 header_tpad => INT

=head2 header_bpad => INT


=head1 METHODS

=head2 $t = Text::ANSITable->new(%attrs) => OBJ

Constructor.

=head2 $t->list_border_styles => LIST

Return the names of available border styles. Border styles will be searched in
C<Text::ANSITable::BorderStyle::*> modules.

=head2 $t->list_color_themes => LIST

Return the names of available color themes. Color themes will be searched in
C<Text::ANSITable::ColorTheme::*> modules.

=head2 $t->get_border_style($name) => HASH

Can also be called as a static method: C<<
Text::ANSITable->get_border_style($name) >>.

=head2 $t->get_color_theme($name) => HASH

Can also be called as a static method: C<<
Text::ANSITable->get_color_theme($name) >>.

=head2 $t->add_row(\@row[, \%styles]) => OBJ

Add a row. Note that row data is not copied, only referenced.

Can also add per-row styles (which can also be done using C<row_style()>).

=head2 $t->add_rows(\@rows[, \%styles]) => OBJ

Add multiple rows. Note that row data is not copied, only referenced.

Can also add per-row styles (which can also be done using C<row_style()>).

=head2 $t->add_row_separator() => OBJ

Add a row separator line.

=head2 $t->get_cell($row_num, $col) => VAL

Get cell value at row #C<$row_num> (starts from zero) and column named/numbered
C<$col>.

=head2 $t->set_cell($row_num, $col, $newval) => VAL

Set cell value at row #C<$row_num> (starts from zero) and column named/numbered
C<$col>. Return old value.

=head2 $t->get_column_style($col, $style) => VAL

Get per-column style for column named/numbered C<$col>.

=head2 $t->set_column_style($col, $style=>$val[, $style2=>$val2, ...])

Set per-column style(s) for column named/numbered C<$col>. Available values for
C<$style>: C<align>, C<valign>, C<pad>, C<lpad>, C<rpad>, C<width>, C<formats>,
C<fgcolor>, C<bgcolor>, C<type>, C<wrap>.

=head2 $t->get_row_style($row_num) => VAL

Get per-row style for row numbered C<$row_num>.

=head2 $t->set_row_style($row_num, $style=>$newval[, $style2=>$newval2, ...])

Set per-row style(s) for row numbered C<$row_num>. Available values for
C<$style>: C<align>, C<valign>, C<height>, C<vpad>, C<tpad>, C<bpad>,
C<fgcolor>, C<bgcolor>.

=head2 $t->get_cell_style($row_num, $col, $style) => VAL

Get per-cell style.

=head2 $t->set_cell_style($row_num, $col, $style=>$newval[, $style2=>$newval2, ...])

Set per-cell style(s). Available values for C<$style>: C<align>, C<valign>,
C<formats>, C<fgcolor>, C<bgcolor>.

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

=head2 ANSITABLE_STYLE => JSON

Can be used to set table's most attributes. Value should be a JSON-encoded hash
of C<< attr => val >> pairs. Example:

 % ANSITABLE_STYLE='{"show_row_separator":1}' ansitable-list-border-styles

will display table with row separator lines after every row.

=head2 ANSITABLE_COLUMN_STYLES => JSON

Can be used to set per-column styles. Interpreted right before draw(). Value
should be a JSON-encoded hash of C<< col => {style => val, ...} >> pairs.
Example:

 % ANSITABLE_COLUMN_STYLES='{"2":{"type":"num"},"3":{"type":"str"}}' ansitable-list-border-styles

will display the bool columns as num and str instead.

=head2 ANSITABLE_ROW_STYLES => JSON

Can be used to set per-row styles. Interpreted right before draw(). Value should
be a JSON-encoded a hash of C<< row_num => {style => val, ...} >> pairs.
Example:

 % ANSITABLE_ROW_STYLES='{"0":{"bgcolor":"000080","vpad":1}}' ansitable-list-border-styles

will display the first row with blue background color and taller height.

=head2 ANSITABLE_CELL_STYLES => JSON

Can be used to set per-cell styles. Interpreted right before draw(). Value
should be a JSON-encoded a hash of C<< "row_num,col" => {style => val, ...} >>
pairs. Example:

 % ANSITABLE_CELL_STYLES='{"1,1":{"bgcolor":"008000"}}' ansitable-list-border-styles

will display the second-on-the-left, second-on-the-top cell with green
background color.


=head1 FAQ

=head2 General

=head3 My table looks garbled when viewed through pager like B<less>!

It's because B<less> escapes ANSI color codes. Try using C<-R> option of B<less>
to display ANSI color codes raw.

Or, try not using boxchar border styles, use the utf8 or ascii version. Try not
using colors.

=head3 How do I hide some columns/rows when drawing?

Use the C<column_filter> and C<row_filter> attributes. For example, given this
table:

 my $t = Text::ANSITable->new;
 $t->columns([qw/one two three/]);
 $t->add_row([$_, $_, $_]) for 1..10;

Doing this:

 $t->row_filter([0, 1, 4]);
 print $t->draw;

will show:

  one | two | three
 -----+-----+-------
    1 |   1 |     1
    2 |   2 |     2
    5 |   5 |     5

Doing this:

 $t->row_filter(sub { my ($row, $idx) = @_; $row->[0] % 2 }

will display:

  one | two | three
 -----+-----+-------
    1 |   1 |     1
    3 |   3 |     3
    5 |   5 |     5
    7 |   7 |     7
    9 |   9 |     9

Doing this:

 $t->column_filter([qw/two one 0/]);

will display:

  two | one | one
 -----+-----+-----
    1 |   1 |   1
    2 |   2 |   2
    3 |   3 |   3
    4 |   4 |   4
    5 |   5 |   5
    6 |   6 |   6
    7 |   7 |   7
    8 |   8 |   8
    9 |   9 |   9
   10 |  10 |  10

Doing this:

 $t->column_filter(sub { my ($colname, $idx) = @_; $colname =~ /t/ });

will display:

  two | three
 -----+-------
    1 |     1
    2 |     2
    3 |     3
    4 |     4
    5 |     5
    6 |     6
    7 |     7
    8 |     8
    9 |     9
   10 |    10

=head2 Formatting data

=head3 How do I format data?

Use the C<formats> per-column style or per-cell style. For example:

 $t->set_column_style('available', formats => [[bool=>{style=>'check_cross'}],
                                               [centerpad=>{width=>10}]]);
 $t->set_column_style('amount'   , formats => [[num=>{decimal_digits=>2}]]);
 $t->set_column_style('size'     , formats => [[num=>{style=>'kilo'}]]);

See L<Data::Unixish::Apply> and L<Data::Unixish> for more details on the
available formatting functions.

=head3 How does the module determine column data type?

Currently: if column name has the word C<date> or C<time> in it, the column is
assumed to contain B<date> data. If column name has C<?> in it, the column is
assumed to be B<bool>. If a column contains only numbers (or undefs), it is
B<num>. Otherwise, it is B<str>.

=head3 How does the module format data types?

Currently: B<num> will be right aligned and applied C<num_data> color (cyan in
the default theme). B<date> will be centered and applied C<date_data> color
(gold in the default theme). B<bool> will be centered and formatted as
check/cross symbol and applied C<bool_data> color (red/green depending on
whether the data is false/true). B<str> will be applied C<str_data> color (no
color in the default theme).

Other color themes might use different colors.

=head3 How do I force column to be of a certain data type?

For example, you have a column named B<deleted> but want to display it as
B<bool>. You can do:

 $t->set_column_type(deleted => type => 'bool');

=head3 How do I wrap long text?

The C<wrap> dux function can be used to wrap text (see: L<Data::Unixish::wrap>).
You'll want to set C<ansi> and C<mb> both to 1 to handle ANSI escape codes and
wide characters in your text (unless you are sure that your text does not
contain those):

 $t->set_column_style('description', formats=>[[wrap => {width=>60, ansi=>1, mb=>1}]]);

=head3 How do I highlight text with color?

The C<ansi::highlight> dux function can be used to highlight text (see:
L<Data::Unixish::ansi::highlight>).

 $t->set_column_style(2, formats => [[highlight => {pattern=>$pat}]]);

=head3 I want to change the default bool cross/check sign representation!

By default, bool columns are shown as cross/check sign. This can be changed,
e.g.:

 $t->set_column_style($colname, type    => 'bool',
                                formats => [[bool => {style=>"Y_N"}]]);

See L<Data::Unixish::bool> for more details.

=head2 Border

=head3 I'm getting 'Wide character in print' error message when I use utf8 border styles!

Add something like this first before printing to your output:

 binmode(STDOUT, ":utf8");

=head3 How to hide borders?

There is currently no C<show_border> attribute. Choose border styles like
C<Default::space_ascii> or C<Default::none_utf8>:

 $t->border_style("Default::none");

=head3 I want to hide borders, and I do not want row separators to be shown!

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

=head3 How to specify colors using names (e.g. red, 'navy blue') instead of RGB?

Use modules like L<Graphics::ColorNames>.

=head3 I'm not seeing colors when output is piped (e.g. to a pager)!

The default is to disable colors when (-t STDOUT) is false. You can force-enable
colors by setting C<use_color> attribute or C<COLOR> environment to 1.

=head3 How to enable 256 colors? I'm seeing only 16 colors.

Use terminal emulators that support 256 colors, e.g. Konsole, xterm,
gnome-terminal, PuTTY/pterm (but the last one has minimal Unicode support).
Better yet, use Konsole or Konsole-based emulators which supports 24bit colors.

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

=head3 I'm using terminal emulator with white background, the texts are not very visible!

Try using the "*_whitebg" themes, as the other themes are geared towards
terminal emulators with black background.

=head3 How to set different background colors for odd/even rows?

Aside from doing C<< $t->set_row_style($row_num, bgcolor=>...) >> for each row,
you can also do this:

 $t->cell_bgcolor(sub { my ($self, %args) = @_; $args{row_num} % 2 ? '202020' : undef });


=head1 TODO/BUGS

Most color themes still look crappy on 256 colors (I develop on Konsole).

Attributes: cell_wrap? (a shorter/nicer version for formats => [[wrap =>
{ansi=>1, mb=>1}]]).

Column styles: show_{left,right}_border (shorter name? {l,r}border?)

Row styles: show_{top,bottom}_border (shorter name? {t,b}border?)

row span? column span?


=head1 SEE ALSO

For collections of border styles, search for C<Text::ANSITable::BorderStyle::*>
modules.

For collections of color themes, search for C<Text::ANSITable::ColorTheme::*>
modules.

Other table-formatting modules: L<Text::Table>, L<Text::SimpleTable>,
L<Text::ASCIITable> (which I usually used), L<Text::UnicodeTable::Simple>,
L<Table::Simple> (uses Moose).

Modules used: L<Text::ANSI::Util>, L<Color::ANSI::Util>.

=cut
