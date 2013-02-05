package Eve::EventTestBase;

use parent qw(Eve::Test);

use strict;
use warnings;

use Test::MockObject;
use Test::More;

use Eve::RegistryStub;

use Eve::Registry;

Eve::EventTestBase->SKIP_CLASS(1);

sub setup {
    my $self = shift;

    $self->{'registry'} = Eve::Registry->new();
    $self->{'event_map'} = $self->{'registry'}->get_event_map();
}

sub test_trigger : Test(6) {
    my $self = shift;

    my $handler_list = [];
    for my $i (0..2) {
        $self->{'event'}->trigger();

        for my $handler (@{$handler_list}) {
            is($handler->call_pos(1), 'handle');
            is_deeply(
                [$handler->call_args(1)],
                [$handler, event => $self->{'event'}]);
        }

        my $handler_mock = Test::MockObject->new()->set_always('handle', 1);
        push(@{$handler_list}, $handler_mock);
        $self->{'event_map'}->bind(
            event_class => ref $self->{'event'},
            handler => $handler_mock);
    }
}

1;
