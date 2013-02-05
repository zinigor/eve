# -*- mode: Perl; -*-
package HttpResourceTemplateTest;

use parent qw(Eve::Test);

use strict;
use warnings;

use Test::Exception;
use Test::More;
use Test::MockObject::Extends;

use File::Spec;
use Data::Dumper;

use Eve::PsgiStub;
use Eve::RegistryStub;
use Eve::TemplateStub;

use Eve::HttpResource::Template;
use Eve::Registry;

sub setup : Test(setup) {
    my $self = shift;

    $self->{'registry'} = Eve::Registry->new();
    $self->{'response'} = $self->{'registry'}->get_http_response();
    $self->{'session'} = $self->{'registry'}->get_session(
        id => undef,
        storage_path => File::Spec->catdir(
            File::Spec->tmpdir(), 'test_session_storage'),
        expiration_interval => 3600);
    $self->{'request'} = Eve::PsgiStub->get_request(
        cookie => 'session_id=' . $self->{'session'}->get_id());
    $self->{'template'} = $self->{'registry'}->get_template(
            path => File::Spec->catdir(
                File::Spec->tmpdir(), 'test_template_dir'),
            compile_path => File::Spec->catdir(
                File::Spec->tmpdir(), 'test_compiled_storage'),
        expiration_interval => 60);
    $self->{'dispatcher'} = $self->{'registry'}->get_http_dispatcher();

    $self->{'content_model'} = Test::MockObject::Extends->new(
        $self->{'registry'}->get_content_model());

    $self->{'default_language'} = Eve::Item::Language->new(
        id => 1, name => 'English', code => 'en', tts_code => 'en');

    $self->{'json'} = Test::MockObject::Extends->new(
        $self->{'registry'}->get_json());

    $self->{'resource_parameter_hash'} = {
        'response' => $self->{'response'},
        'session_constructor' => sub { return $self->{'session'}; },
        'dispatcher' => $self->{'dispatcher'},
        'json' => $self->{'json'},
        'template' => $self->{'template'},
        'template_file' => 'empty.html',
        'content_model' => $self->{'content_model'},
        'default_language' => $self->{'default_language'},
        'text_var_hash' => {}};
}

sub test_get : Test(2) {
    my $self = shift;

    $self->{'resource_parameter_hash'}->{'template_file'} = 'some.html';

    for my $var_hash ({'some' => 'var'}, {'another' => 'var'}) {
        my $resource = Eve::HttpResource::Template->new(
            %{$self->{'resource_parameter_hash'}},
            response => $self->{'registry'}->get_http_response(),
            template_var_hash => $var_hash,
            content_type => undef,
            charset => undef);

        my $response = $resource->process(
            matches_hash => {}, request => $self->{'request'});

        my $expected_response = $self->{'registry'}->get_http_response();
        $expected_response->set_status(code => 200);
        $expected_response->set_body(
            text => Digest::MD5::md5_hex(Dumper(
                $self->{'resource_parameter_hash'}->{'template_file'},
                {
                    %{$var_hash},
                    'get_text' => sub {},
                    'session' => $self->{'session'},
                    'dispatcher' => $self->{'dispatcher'},
                    'request' => $self->{'request'},
                    'default_language' => $self->{'default_language'}})));
        is(
            $response->get_text(),
            $expected_response->get_text());
    }
}

sub test_content_type : Test(3) {
    my $self = shift;

    for my $type ('text/html', 'text/plain', 'image/lolcat') {
        my $resource = Eve::HttpResource::Template->new(
            %{$self->{'resource_parameter_hash'}},
            template_var_hash => {},
            content_type => $type,
            charset => undef);

        my $response = $resource->process(
            matches_hash => {}, request => $self->{'request'});

        my $expected_response = $self->{'registry'}->get_http_response();
        $expected_response->set_header(name => 'Content-type', value => $type);
        $expected_response->set_header(name => 'Content-Length', value => 0);

        is($response->get_text(), $expected_response->get_text());
    }
}

sub test_charset : Test(2) {
    my $self = shift;

    for my $charset ('UTF-8', 'windows-1251') {
        my $resource = Eve::HttpResource::Template->new(
            %{$self->{'resource_parameter_hash'}},
            template_var_hash => {},
            content_type => undef,
            charset => $charset);

        my $response = $resource->process(
            matches_hash => {}, request => $self->{'request'});

        my $expected_response = $self->{'registry'}->get_http_response();
        $expected_response->set_header(name => 'charset', value => $charset);
        $expected_response->set_header(name => 'Content-Length', value => 0);

        is($response->get_text(), $expected_response->get_text());
    }
}

sub test_get_exception : Test(2) {
    my $self = shift;

    my $resource = Eve::HttpResource::Template->new(
        %{$self->{'resource_parameter_hash'}},
        template_var_hash => {},
        require_auth => 1);

    $self->{'session'}->clear_parameter(name => 'account_id');

    throws_ok(
        sub { $resource->process(
                  matches_hash => {}, request => $self->{'request'}) },
        'Eve::Exception::Http::401Unauthorized');

    $self->{'session'}->set_parameter(name => 'account_id', value => 1);

    lives_ok(
        sub {
            $resource->process(
                matches_hash => {}, request => $self->{'request'});
        });
}

sub test_no_language_set_exception : Test {
    my $self = shift;

    my $resource = Eve::HttpResource::Template->new(
        %{$self->{'resource_parameter_hash'}},
        template_var_hash => {});

    $self->{'session'}->set_parameter(name => 'account_id', value => 1);

    $self->{'content_model'}->set_always(
        'get_language_list_by_account_id', []);

    throws_ok(
        sub { $resource->process(
                  matches_hash => {}, request => $self->{'request'})
        },
        'Eve::Exception::Data::LanguageNotSet');
}

sub test_get_text : Test(8) {
    my $self = shift;

    my $text_var_hash = {
        1 => {
            'some_filename.tmpl' => {
                'some_var' => 'Some value',
                'another_var' => 'Another value'},
            '/another/filename.tmpl' => {
                'third_var' => 'Third value',
                'fourth_var' => 'Fourth value'}},
        2 => {
            'some_filename.tmpl' => {
                'some_var' => 'Some overridden value'}}};

    my $resource = Eve::HttpResource::Template->new(
        %{$self->{'resource_parameter_hash'}},
        text_var_hash => $text_var_hash,
        default_language => Eve::Item::Language->new(
            id => 1, name => 'Japanese', code => 'jp', tts_code => 'jp'));

    my $var_list_hash = {
        'some_filename.tmpl' => ['some_var', 'another_var'],
        '/another/filename.tmpl' => ['third_var', 'fourth_var']};

    for my $filename (keys %{$var_list_hash}) {
        for my $var_name (@{$var_list_hash->{$filename}}) {
            my $result =
                (defined $text_var_hash->{2}->{$filename}->{$var_name}) ?
                $text_var_hash->{2}->{$filename}->{$var_name} :
                $text_var_hash->{1}->{$filename}->{$var_name};

            my $text = $resource->get_text(2, $filename, $var_name);
            isnt($text, undef, 'Text should be returned for ' . $var_name);
            is(
                $text,
                $result,
                'The text shoud be equal to the value from the hash');
        }
    }
}

sub test_get_text_standards : Test(4) {
    my $self = shift;

    my $text_var_hash = {
        1 => {
            'std_server_template' => {
                'persistent_var' => 'Some persistent value',
                'also_persistent_var' => 'Another persistent value',
            }},
        2 => {
            'std_server_template' => {
                'persistent_var' => 'Some overridden persistent value',
            }}};

    my $resource = Eve::HttpResource::Template->new(
        %{$self->{'resource_parameter_hash'}},
        text_var_hash => $text_var_hash,
        default_language => Eve::Item::Language->new(
            id => 1, name => 'Japanese', code => 'jp', tts_code => 'jp'));

    my $var_list = ['persistent_var', 'also_persistent_var'];

    my $filename = 'std_server_template';

    for my $var_name (@{$var_list}) {
        my $result =
            (defined $text_var_hash->{2}->{$filename}->{$var_name}) ?
            $text_var_hash->{2}->{$filename}->{$var_name} :
            $text_var_hash->{1}->{$filename}->{$var_name};

        my $text = $resource->get_text(
            2, 'some_irrelevant_filename', $var_name);
        isnt($text, undef, 'Standard text should be returned for ' . $var_name);
        is(
            $text,
            $result,
            'The standard text shoud be equal to the value from the hash');
    }
}

sub test_get_text_no_default_language_exception : Test {
    my $self = shift;

    my $resource = Eve::HttpResource::Template->new(
        %{$self->{'resource_parameter_hash'}},
        text_var_hash => {
            2 => {
                'some_filename.tmpl' => {
                    'some_var' => 'Some overridden value'}}},
        default_language => Eve::Item::Language->new(
            id => 1, name => 'Japanese', code => 'jp', tts_code => 'jp'));

    throws_ok(
        sub {
            $resource->get_text(3, 'some_filename.tmpl', 'some_var');
        },
        'Eve::Exception::Data::TemplateTextNotFound');
}

sub test_get_text_no_default_exception : Test(4) {
    my $self = shift;

    my $resource = Eve::HttpResource::Template->new(
        %{$self->{'resource_parameter_hash'}},
        text_var_hash => {
            1 => {
                'some_filename.tmpl' => {'another_var' => 'No defaults here'},
            },
            2 => {
                'some_filename.tmpl' => {
                    'some_var' => 'Some overridden value'}}},
        default_language => Eve::Item::Language->new(
            id => 1, name => 'Japanese', code => 'jp', tts_code => 'jp'));

    lives_ok(
        sub {
            $resource->get_text(2, 'some_filename.tmpl', 'another_var');
        },
        'Should not throw an exception when there is a default match');

    lives_ok(
        sub {
            $resource->get_text(2, 'some_filename.tmpl', 'some_var');
        },
        'Should not throw an exception when there is a direct match');

    throws_ok(
        sub {
            $resource->get_text(2, 'some_filename.tmpl', 'no_default_var');
        },
        'Eve::Exception::Data::TemplateTextNotFound',
        'Should throw an exception when there is no default variable value');

    throws_ok(
        sub {
            $resource->get_text(2, 'no_default_filename.tmpl', 'some_var');
        },
        'Eve::Exception::Data::TemplateTextNotFound',
        'Should throw an exception when there is no default filename entry');
}

sub test_get_text_as_json : Test(4) {
    my $self = shift;

    my $text_var_hash = {
        1 => {
            'std_server_template' => {},
            'filename.tmpl' => {'some_var' => 'Some value'}},
        2 => {
            'std_server_template' => {},
            'filename.tmpl' => {'some_var' => 'Some overridden value'}}};

    my $resource = Eve::HttpResource::Template->new(
        %{$self->{'resource_parameter_hash'}},
        text_var_hash => $text_var_hash,
        default_language => Eve::Item::Language->new(
            id => 1, name => 'Japanese', code => 'jp', tts_code => 'jp'));

    $self->{'json'}->set_always('encode', 'some_value');

    for my $language_id (keys %{$text_var_hash}) {
        is('some_value', $resource->get_text_as_json(
               $language_id, 'filename.tmpl'));

        while (my @args = $self->{'json'}->next_call()) {
            is_deeply(
                \@args,
                ['encode',
                 [$self->{'json'},
                  'reference',
                  $text_var_hash->{$language_id}->{'filename.tmpl'}]]);
        }
    }
}

sub test_get_text_as_json_defaults : Test(4) {
    my $self = shift;

    my $text_var_hash = {
        1 => {'std_server_template' => {'some_var' => 'Some value'}},
        2 => {'std_server_template' => {
            'some_var' => 'Some overridden value'}}};

    my $resource = Eve::HttpResource::Template->new(
        %{$self->{'resource_parameter_hash'}},
        text_var_hash => $text_var_hash,
        default_language => Eve::Item::Language->new(
            id => 1, name => 'Japanese', code => 'jp', tts_code => 'jp'));

    $self->{'json'}->set_always('encode', 'some_value');

    for my $language_id (keys %{$text_var_hash}) {
        is('some_value', $resource->get_text_as_json(
               $language_id, 'filename.tmpl'));

        while (my @args = $self->{'json'}->next_call()) {
            is_deeply(
                \@args,
                ['encode',
                 [$self->{'json'},
                  'reference',
                  $text_var_hash->{$language_id}->{'std_server_template'}]]);
        }
    }
}

1;
