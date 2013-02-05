# -*- mode: Perl; -*-
package Eve::ItemTestBase;

use parent qw(Eve::Test);

use strict;
use warnings;

use Test::More;
use Test::Exception;

Eve::ItemTestBase->SKIP_CLASS(1);

sub get_argument_list {
    return {};
}

sub test_init {}

sub test_constants {}

sub test_eq : Test(1) {
    my $self = shift;

    throws_ok(sub { $self->{'item'}->eq() }, 'Eve::Error::NotImplemented');
}

1;
