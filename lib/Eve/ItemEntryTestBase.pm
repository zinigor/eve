# -*- mode: Perl; -*-
package Eve::ItemEntryTestBase;

use parent qw(Eve::ItemTestBase);

use strict;
use warnings;

use Test::More;

Eve::ItemEntryTestBase->SKIP_CLASS(1);

sub get_argument_list {
    my $self = shift;

    return {
        %{$self->SUPER::get_argument_list()},
        'id' => 123,
        'created' => '2011-03-16 17:03:45',
        'modified' => '2011-03-16 17:04:33',
        'status' => 1};
}

sub test_init {
    my $self = shift;

    $self->SUPER::test_init();

    is($self->{'item'}->id, 123);
    is($self->{'item'}->created, '2011-03-16 17:03:45');
    is($self->{'item'}->modified, '2011-03-16 17:04:33');
    is($self->{'item'}->status, 1);
}

sub test_constants {
    my $self = shift;

    $self->SUPER::test_constants();

    is($self->{'item'}->STATUS_ACTIVE, 1);
}

1;
