package Text::ANSITable::StyleSet::AltRow;

use 5.010;
use Moo;
use namespace::clean;

has odd_bgcolor  => (is => 'rw');
has even_bgcolor => (is => 'rw');
has odd_fgcolor  => (is => 'rw');
has even_fgcolor => (is => 'rw');

sub summary {
    "Set different foreground and/or background color for odd/even rows";
}

sub apply {
    my ($self, $table) = @_;

    $table->add_cond_row_style(
        sub {
            my ($t, %args) = @_;
            my %styles;
            # because we count from 0
            if ($_ % 2 == 0) {
                $styles{bgcolor} = $self->odd_bgcolor
                    if defined $self->odd_bgcolor;
                $styles{fgcolor}=$self->odd_fgcolor
                    if defined $self->odd_bgcolor;
            } else {
                $styles{bgcolor} = $self->even_bgcolor
                    if defined $self->even_bgcolor;
                $styles{fgcolor} = $self->even_fgcolor
                    if defined $self->even_bgcolor;
            }
            \%styles;
        },
    );
}

1;

=for Pod::Coverage ^(summary|apply)$

=head1 ATTRIBUTES

=head2 odd_bgcolor

=head2 odd_fgcolor

=head2 even_bgcolor

=head2 even_fgcolor
