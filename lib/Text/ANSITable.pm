package Text::ANSITable;

use 5.010;
use strict;
use warnings;

# VERSION

our %border_styles = (
    # charset
    # code to print when start drawing borders
    # code to print after drawing borders
    single_ascii  => ['.', '-', '+', '.', '|', '+', ''],
    single_eascii => [map {} ('l', 'q', 'k', '', )],
    single_utf8   => [''],
);

our %color_themes = (
);

sub new {
    my ($class, %args) = @_;
    $args{rows} = [];
    $args{cols} = [];
    bless \%args, $class;
}

sub add_row {
}

1;
#ABSTRACT: Create a nice formatted table using extended ASCII and ANSI colors

=head1 SYNOPSIS


=head1 DESCRIPTION

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


=head1 SEE ALSO

L<Text::Table>

L<Text::SimpleTable>

L<Text::ASCIITable>, which I usually used.

L<Text::UnicodeTable::Simple>

L<Table::Simple> (uses Moose)

=cut
