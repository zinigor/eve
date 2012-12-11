package Eve::HttpDispatcher;

use parent qw(Eve::Class);

use strict;
use warnings;

use Eve::Event::HttpResponseReady;
use Eve::Exception;

=head1 NAME

B<Eve::HttpDispatcher> - an event handler for HTTP request events.

=head1 SYNOPSIS

    use Eve::HttpDispatcher;

    my $dispatcher = Eve::HttpDispatcher->new(
        request_constructor => $request_constructor,
        response => $response,
        base_uri => $base_uri,
        alias_base_uri_list => [$alias_base_uri, $another_alias_base_uri],
        event_map => $event_map);

    $dispatcher->bind(
        name => $name
        pattern => $pattern,
        resource_constructor => $resource_constructor);

    $dispatcher->bind(
        name => $name_404
        pattern => $pattern_404,
        resource_constructor => $resource_constructor_404,
        exception => 'Eve::Exception::Http::404NotFound');

    $dispatcher->handle(event => $event);

=head1 DESCRIPTION

B<Eve::HttpDispatcher> class is a central component to a web
service application.

=head3 Constructor arguments

=over 4

=item C<request_constructor>

a code reference that returns an HTTP request object when passed an
environment hash

=item C<response>

an HTTP response object

=item C<event_map>

an event map object.

=item C<base_uri>

a base URI object used for resource binding.

=item C<alias_base_uri_list>

(optional) a reference to a list of additional base URI objects that
will be used for resource matching.

=back

=cut

sub init {
    my ($self, %arg_hash) = @_;
    Eve::Support::arguments(
        \%arg_hash,
        my ($request_constructor, $response, $event_map, $base_uri),
        my $alias_base_uri_list = []);

    $self->{'_request_constructor'} = $request_constructor;
    $self->{'_response'} = $response;
    $self->{'_event_map'} = $event_map;
    $self->{'_base_uri'} = $base_uri;

    $self->{'_base_uri_list'} = [$base_uri, @{$alias_base_uri_list}];

    $self->{'_uri_map'} = {};
    $self->{'_name_map'} = {};
    $self->{'_exception_name_hash'} = {};

    return;
}

=head1 METHODS

=head2 B<bind()>

Binds an HTTP resource.

=head3 Arguments

=over 4

=item C<name>

a name identifying the binding

=item C<pattern>

an URI pattern string that can contain placeholders

=item C<base_uri>

a URI object that represents a base URL for the binding resource

=item C<resource_constructor>

a code reference that returns an HTTP resource object

=item C<exception>

(optional) an HTTP exception class name that the bound resource should
be used to handle. B<Note>: there can be only one resource bound to
handle a certain exception.

=back

=head3 Throws

=over 3

=item C<Eve::Exception::HttpDispatcher>

if either name or compound URI or exception class name is not unique.

=back

=cut

sub bind {
    my ($self, %arg_hash) = @_;
    Eve::Support::arguments(
        \%arg_hash, my ($name, $pattern, $resource_constructor),
        my $exception = \undef);

    if (exists $self->_uri_map->{$pattern}) {
        Eve::Error::HttpDispatcher->throw(
            message => 'Binding URI must be unique: '.$pattern);
    }

    if (exists $self->_name_map->{$name}) {
        Eve::Error::HttpDispatcher->throw(
            message => 'Binding name must be unique: '.$name);
    }

    # Constructing all possible URIs that this resource is supposed to match
    # using the base URI as well as possible aliases
    my $uri_list = [];
    for my $uri (@{$self->_base_uri_list}) {
        my $map_uri = $uri->clone();
        $map_uri->path_concat(string => $pattern);

        push(@{$uri_list}, $map_uri);
    }

    $self->_uri_map->{$pattern} = {
        'resource' => $resource_constructor->(),
        'uri_list' => $uri_list};

    $self->_name_map->{$name} = {
        'pattern' => $pattern, 'uri_list' => $uri_list};

    if (defined $exception) {
        if (exists $self->_exception_name_hash->{$exception}) {
            Eve::Error::HttpDispatcher->throw(
                message => 'Exception name must be unique: ' . $exception);
        }
        $self->_exception_name_hash->{$exception} = $pattern;
    }

    return;
}

=head2 B<get_uri()>

=head3 Arguments

=over 4

=item C<name>

a name identifying the binding

=back

=head3 Returns

A URI bound to the resource name.

=head3 Throws

=over 3

=item C<Eve::Error::HttpDispatcher>

When there is no resource with the requested name.

=back

=cut

sub get_uri {
    my ($self, %arg_hash) = @_;
    Eve::Support::arguments(\%arg_hash, my $name);

    if (not exists $self->_name_map->{$name}) {
        Eve::Error::HttpDispatcher->throw(
            message => 'There is no resource with such name: '.$name);
    }

    # We are relying on the fact that the page URI generated by the
    # base URI is always the first in the uri list for the specified
    # name.
    return $self->_name_map->{$name}->{'uri_list'}->[0];
}

=head2 B<handle()>

Chooses a resource using the request URI and delegates control to the
resource's C<process()> method. It also passes placeholder matches
into this method.

=head3 Arguments

=over 4

=item C<event>

a C<Eve::Event::HttpRequestReceived> object.

=back

=head3 Throws

=over 3

=item C<Eve::Exception::Http::404NotFound>

if no resources match the request and no resources that handle the
C<Eve::Exception::Http::404NotFound> are bound.

=back

=cut

sub handle {
    my ($self, %arg_hash) = @_;
    Eve::Support::arguments(\%arg_hash, my $event);

    $self->{'_request'} =
        $self->_request_constructor->(env_hash => $event->env_hash);

    my $response;

    eval {
        for my $key (keys %{$self->_uri_map}) {
            my $request_uri = $self->_request->get_uri();

            for my $uri (@{$self->_uri_map->{$key}->{'uri_list'}}) {
                my $match_hash = $uri->match(uri => $request_uri);
                if ($match_hash) {
                    $response = $self->_uri_map->{$key}->{'resource'}->process(
                        matches_hash => $match_hash,
                        request => $self->_request);
                    return;
                }
            }
        }

        Eve::Exception::Http::404NotFound->throw();
    };

    my $e;
    if ($e = Eve::Exception::Base->caught()) {
        if (defined $self->_exception_name_hash->{ref $e}){
            my $resource =
                $self->_uri_map->{$self->_exception_name_hash->{ref $e}}->{
                    'resource'};

            $response = $resource->process(
                matches_hash => {'exception' => $e},
                request => $self->_request);
        } else {
            $e->throw();
        }
    } elsif ($e = Exception::Class->caught()) {
        ref $e ? $e->rethrow() : die $e;
    }

    $event->response = $response;

    return;
}

=head1 SEE ALSO

=over 4

=item L<Eve::Class>

=item L<Eve::Event::HttpResponseReady>

=item L<Eve::Exception>

=item L<Eve::HttpResource>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Igor Zinovyev.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=head1 AUTHOR

=over 4

=item L<Sergey Konoplev|mailto:gray.ru@gmail.com>

=item L<Igor Zinovyev|mailto:zinigor@gmail.com>

=back

=cut

1;
