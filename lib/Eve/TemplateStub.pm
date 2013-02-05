package Eve::TemplateStub;

use strict;
use warnings;

use Test::MockObject;
use Test::MockObject::Extends;

use Digest::MD5 ();
use Data::Dumper;

my $stash_stub = {};

sub mock_template {
    my @args = @_;

    my $template_mock = Test::MockObject::Extends->new('Template');

    $template_mock->mock(
        'new',
        sub {
            my ($self, undef, $arg_hash) = @_;

            my $result = $self;
            if ($arg_hash->{'INCLUDE_PATH'} eq '/some/buggy/path') {
                $result = undef
            }

            return $result;
        });

    $template_mock->mock(
        'error', sub { return 'Oops'; });

    $template_mock->mock(
        'process',
        sub {
            my (undef, $file, $var_hash, $output_ref) = @_;

            my $result = 1;
            if ($file eq 'buggy.html') {
                $result = undef;
            }

            if ($file eq 'empty.html') {
                ${$output_ref} = '';
            } elsif ($file eq 'dump.html') {
                local $Data::Dumper::Maxdepth = 2;
                ${$output_ref} = Dumper($var_hash);
            } else {
                delete $var_hash->{'matches_hash'};
                ${$output_ref} = Digest::MD5::md5_hex(Dumper($file, $var_hash));
            }

            return $result;
        });

    return $template_mock->new(@args);
}

sub main {
    Test::MockObject::Extends->new('Template')->fake_module(
        'Template', 'new' => sub { return mock_template(@_); });
    Test::MockObject::Extends->new('Template')->fake_module(
        'Template::Stash::XS', 'new' => sub { return $stash_stub; });
}

main();

1;
