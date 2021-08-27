# no code
## no critic: TestingAndDebugging::RequireUseStrict
package ColorTheme::Text::ANSITable::Standard::GradationWhiteBG;

# AUTHORITY
# DATE
# DIST
# VERSION

use parent 'ColorThemeBase::Static::FromStructColors';

use ColorTheme::Text::ANSITable::Standard::Gradation;
use Function::Fallback::CoreOrPP qw(clone);

our %THEME = %{ clone(\%ColorTheme::Text::ANSITable::Standard::Gradation::THEME) };
$THEME{summary} = 'Gradation (for terminal with white background)';

$THEME{args}{border1_fg}{default} = '000000';
$THEME{args}{border2_fg}{default} = 'cccccc';

$THEME{items}{header_bg} = 'cccccc';
$THEME{items}{num_data}  = '006666';
$THEME{items}{date_data} = '666600';
$THEME{items}{bool_data} = sub {
    my ($self, $name, $args) = @_;
    $args->{orig_data} ? '00cc00' : 'cc0000';
};

1;
# ABSTRACT:
