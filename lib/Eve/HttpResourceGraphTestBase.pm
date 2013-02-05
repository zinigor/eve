# -*- mode: Perl; -*-
package Eve::HttpResourceGraphTestBase;

use parent qw(Eve::Test);

use strict;
use warnings;

use Test::More;

use Eve::RegistryStub;

use Eve::Registry;

Eve::HttpResourceGraphTestBase->SKIP_CLASS(1);

sub setup {
    my $self = shift;

    $self->{'registry'} = Eve::Registry->new();
    $self->{'session'} = $self->{'registry'}->get_session(id => undef);
}

sub set_dispatcher {
    my ($self, $request) = @_;

    $self->{'dispatcher'} = Eve::HttpDispatcher->new(
        request_constructor => sub {
            return $request;
        },
        response => $self->{'registry'}->get_http_response(),
        event_map => $self->{'registry'}->get_event_map(),
        base_uri => $self->{'registry'}->get_base_uri());

    $self->{'resource'} = $self->{'resource_constructor'}->(
        dispatcher => $self->{'dispatcher'});

    for my $binding_hash (@{$self->{'dispatcher_binding_list'}}) {
        $self->{'dispatcher'}->bind(%{$binding_hash});
    }

    return;
}

sub do_test_read {
    my ($self, $data_hash_list) = @_;

    $self->do_test($data_hash_list, 'GET');
}

sub do_test_publish {
    my ($self, $data_hash_list) = @_;

    $self->do_test($data_hash_list, 'POST');
}

sub do_test_remove {
    my ($self, $data_hash_list) = @_;

    $self->do_test($data_hash_list, 'DELETE');
}

sub do_test {
    my ($self, $data_hash_list, $method) = @_;

    for my $data_hash (@{$data_hash_list}) {

        my $request = Eve::PsgiStub->get_request(
            method => $method,
            uri => $data_hash->{'uri_hash'}->{'uri_string'},
            query => $data_hash->{'uri_hash'}->{'query_string'},
            host => 'example.com',
            body => $data_hash->{'request_body'},
            cookie => 'session_id=' . $self->{'session'}->get_id());

        if (defined $data_hash->{'upload_hash'}) {
            $request->cgi->{'env'}->{'plack.request.upload'} =
                $data_hash->{'upload_hash'};
        }

        $self->set_dispatcher($request);

        $self->set_session_parameters($data_hash->{'session_hash'});
        $self->mock_gateway_methods($data_hash->{'gateway_list'});

        my $event = Eve::Event::PsgiRequestReceived->new(
            event_map => $self->{'registry'}->get_event_map(),
            env_hash => {});

        $self->{'dispatcher'}->handle(event => $event);

        $self->assert_response(
            $event->response, 200, $data_hash->{'resource_result'});
    }
}

sub set_session_parameters {
    my ($self, $session_hash) = @_;

    for my $parameter_name (keys %{$session_hash}) {
        $self->{'session'}->set_parameter(
            name => $parameter_name,
            value => $session_hash->{$parameter_name});
    }
}

sub mock_gateway_methods {
    my ($self, $gateway_list) = @_;

    for my $gateway_data_hash (@{$gateway_list}) {
        $gateway_data_hash->{'object'}->mock(
            $gateway_data_hash->{'method'},
            sub {
                shift;
                if (not defined $gateway_data_hash->{'no_argument_check'}) {
                    is_deeply(
                        {@_},
                        $gateway_data_hash->{'arguments'},
                        'Gateway method arguments for '
                        . $gateway_data_hash->{'method'}
                        . ' method.');
                }

                return $gateway_data_hash->{'result'};
            });
    }
}

sub assert_response {
    my ($self, $response, $code, $body) = @_;

    if (ref $body eq 'Regexp') {
        like($response->get_text, $body);

    } else {

        my $expected_response = $self->{'registry'}->get_http_response()->new();
        $expected_response->set_header(
            name => 'Content-Type', value => 'text/javascript');
        $expected_response->set_status(code => $code);
        $expected_response->set_body(
            text => $self->{'registry'}->get_json()->encode(reference => $body));

        is(
            $response->get_text(),
            $expected_response->get_text(),
            'Response text');
    }
}

1;
