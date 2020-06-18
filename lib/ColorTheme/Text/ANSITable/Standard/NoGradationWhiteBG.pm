package ColorTheme::Text::ANSITable::Standard::NoGradationWhiteBG;

# AUTHORITY
# DATE
# DIST
# VERSION

use parent 'ColorThemeBase::Static::FromStructColors';

use Text::ANSITable::ColorTheme::Default::gradation_whitebg;
use Function::Fallback::CoreOrPP qw(clone);

our %THEME = %{ clone(\%Text::ANSITable::ColorTheme::Default::gradation_whitebg::THEME) };
$THEME{summary} = 'Default (no gradation, for white background)';

delete $THEME{description};

delete $THEME{args}{border1};
delete $THEME{args}{border2};

$THEME{colors}{border} = '666666';

1;
# ABSTRACT:
