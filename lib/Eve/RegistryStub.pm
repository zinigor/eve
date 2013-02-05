package Eve::RegistryStub;

use strict;
use warnings;

no warnings qw(redefine);

use Test::MockObject::Extends;

use Eve::Registry;

sub main {
    my $init = \&Eve::Registry::init;

    *Eve::Registry::new = sub {
        my $self = &Eve::Class::new(@_);

        return Test::MockObject::Extends->new($self);
    };

    *Eve::Registry::init = sub {
        my $self = shift;

        $init->(
            $self,
            base_uri_string => 'http://example.com',
            email_from_string => 'Someone <someone@example.com>',
            session_storage_path => File::Spec->catdir(
                File::Spec->tmpdir(), 'test_session_storage'),
            session_expiration_interval => 3600,
            @_);
    };
}

main();

1;
