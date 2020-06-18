package Text::ANSITable::ColorTheme::Default::NoGradation;

# AUTHORITY
# DATE
# DIST
# VERSION

use parent 'ColorThemeBase::Static::FromStructColors';

use Text::ANSITable::ColorTheme::Default::gradation;
use Function::Fallback::CoreOrPP qw(clone);

our %THEME = %{ clone(\%Text::ANSITable::ColorTheme::Default::gradation::THEME) };
$THEME{summary} = 'No gradation, for black background';

delete $THEME{description};

delete $THEME{args}{border1};
delete $THEME{args}{border2};

$THEME{colors}{border} = '666666';

1;
# ABSTRACT:
