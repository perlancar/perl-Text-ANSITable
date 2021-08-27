# no code
## no critic: TestingAndDebugging::RequireUseStrict
package ColorTheme::Text::ANSITable::Standard::NoGradation;

# AUTHORITY
# DATE
# DIST
# VERSION

use parent 'ColorThemeBase::Static::FromStructColors';

use ColorTheme::Text::ANSITable::Standard::Gradation;
use Function::Fallback::CoreOrPP qw(clone);

our %THEME = %{ clone(\%ColorTheme::Text::ANSITable::Standard::Gradation::THEME) };
$THEME{summary} = 'No gradation, for black background';

delete $THEME{description};

delete $THEME{args}{border1};
delete $THEME{args}{border2};

$THEME{items}{border} = '666666';

1;
# ABSTRACT:
