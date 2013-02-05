# -*- mode: Perl; -*-
package Eve::GatewayPgSqlTestBase;

use parent qw(Eve::Test);

use strict;
use warnings;

use Eve::RegistryStub;

use Eve::Registry;

Eve::GatewayPgSqlTestBase->SKIP_CLASS(1);

sub setup {
    my $self = shift;

    my $registry = Eve::Registry->new();
    $self->{'pgsql'} = $registry->get_pgsql();
    $self->{'dbh'} = $self->{'pgsql'}->get_connection()->dbh;
}

1;
