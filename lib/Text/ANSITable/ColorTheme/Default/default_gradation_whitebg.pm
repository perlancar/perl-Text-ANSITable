package Text::ANSITable::ColorTheme::Default::gradation_whitebg;

# AUTHORITY
# DATE
# DIST
# VERSION

use parent 'ColorThemeBase::Static::FromStructColors';

use Text::ANSITable::ColorTheme::Default::gradation;
use Function::Fallback::CoreOrPP qw(clone);

our %THEME = %{ clone(\%Text::ANSITable::ColorTheme::Default::gradation::THEME) };
$THEME{summary} = 'Default (for terminal with white background)';

$THEME{args}{border1_fg}{default} = '000000';
$THEME{args}{border2_fg}{default} = 'cccccc';

$THEME{colors}{header_bg} = 'cccccc';
$THEME{colors}{num_data}  = '006666';
$ct->{colors}{date_data} = '666600';
$ct->{colors}{bool_data} = sub {
    my ($self, $name, $args) = @_;
    $args->{orig_data} ? '00cc00' : 'cc0000';
};

1;
# ABSTRACT:
