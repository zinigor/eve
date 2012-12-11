package Eve::HttpResource::Template;

use parent qw(Eve::HttpResource);

use utf8;
use strict;
use autodie;
use warnings;
use open        qw(:std :utf8);
use charnames   qw(:full);

use Encode qw();

=head1 NAME

B<Eve::HttpResource::Template> - a simple HTTP resource with a template.

=head1 SYNOPSIS

    use Eve::HttpResource::Template;

    # Bind it to an URL using the HTTP resource dispatcher. See
    # B<Eve::HttpDispatcher> class.

    my $resource = Eve::HttpResource::Template->new(
        response => $response,
        session_constructor => $session_constructor,
        dispatcher => $dispatcher,
        template => $template,
        template_file => 'template.html',
        template_var_hash => {'some_var' => 1, 'other_var' => 2},
        require_auth => 1,
        content_type => 'text/plain',
        charset => 'CP1251',
        text_var_hash => $text_var_hash);

    $dispatcher->bind(
        name => 'some_unique_name',
        pattern => '/some_uri',
        base_uri => $some_base_uri,
        resource_constructor => sub {
            return $resource;
        });

=head1 DESCRIPTION

B<Eve::HttpResource::Template> is a simple HTTP resource that only
displays a parsed template. All the templates have the following
objects available in their scope:

=over 4

=item C<session>

an instance of the B<Eve::Session> object for the current user,

=back

=head3 Constructor arguments

=over 4

=item C<response>

an HTTP response object,

=item C<session_constructor>

a reference to a subroutine that returns a session object,

=item C<dispatcher>

an HTTP dispatcher object,

=item C<template>

a template object,

=item C<template_file>

a template file name,

=item C<template_var_hash>

(optional) a hash of variables to be passed to the processed template,
defaults to an empty hash,

=item C<require_auth>

(optional) if a user is not authenticated, throw a
C<Eve::Exception::Http::401Unauthorized>,

=item C<content_type>

(optional) response content-type, defaults to C<text/html>,

=item C<charset>

(optional) response character set, defaults to C<UTF-8>.

=item C<text_var_hash>

(optional) a hash that contains text variables for templates with the
following structure:

    language_id => {
        file_path => {
            var_name_1 => value,
            var_name_2 => another_value,
            ...
        },
        ...
    },
    ...

=item C<default_language_id>

(optional) a default language id, if not specified will default to 2
(English for historical reasons).

=back

=cut

sub init {
    my ($self, %arg_hash) = @_;
    my $arg_hash = Eve::Support::arguments(\%arg_hash,
        my ($template, $template_file, $content_model),
        my (
            $template_var_hash,
            $require_auth,
            $require_language,
            $content_type,
            $charset,
            $text_var_hash,
            $default_language_id) =
            ({}, \undef, 1, 'text/html', \undef, {}, 2));

    $self->{'_template'} = $template;
    $self->{'_template_file'} = $template_file;
    $self->{'_template_var_hash'} = $template_var_hash;
    $self->{'_require_auth'} = $require_auth;
    $self->{'_require_language'} = $require_language;
    $self->{'_content_type'} = $content_type;
    $self->{'_charset'} = $charset;
    $self->{'_text_var_hash'} = $text_var_hash;
    $self->{'_default_language_id'} = $default_language_id;

    $self->{'_content_model'} = $content_model;

    $self->SUPER::init(%{$arg_hash});

    return;
}

=head2 METHODS

=head2 B<get_text()>

Returns a textual representation of a variable name for a given
language and file name.

=head3 Arguments

This method is an exception from the usual method parameter passing
convention. To call it from a template more easily it takes a regular
list of unnamed parameters in the following sequence:

    $resource->get_text($language_id, $file_name, $var_name);

=head3 Returns

a string.

=head3 Throws

=over 4

=item C<Eve::Exception::TemplateTextNotFound>

when there is no text variable set for the specified language and
filename, nor there is a default value for this filename set for the
default language.

=back

=cut

sub get_text {
    my ($self, $language_id, $file_name, $var_name) = @_;

    my $language_hash = $self->_text_var_hash->{$language_id};
    my $default_language_hash =
        $self->_text_var_hash->{$self->_default_language_id};

    if (not defined $language_hash or not defined $default_language_hash) {
        Eve::Exception::Data::TemplateTextNotFound->throw(
            message =>
                'Language with id ' . $language_id
                . ' not found for file ' . $file_name);
    }

    if (not defined $language_hash->{$file_name}
        or not defined $default_language_hash->{$file_name}) {

        if ($file_name eq 'std_server_template') {
            Eve::Exception::Data::TemplateTextNotFound->throw(
                message => 'File ' . $file_name . ' entry not found');
        } else {
            return $self->get_text(
                $language_id, 'std_server_template', $var_name);
        }
    }

    my $filename_hash = {
        %{$default_language_hash->{$file_name}},
        %{$language_hash->{$file_name}}
    };

    if (not defined $filename_hash->{$var_name}) {
        Eve::Exception::Data::TemplateTextNotFound->throw(
            message =>
                'Template variable '
                . $var_name . ' entry not found for file ' . $file_name);
    }

    return $filename_hash->{$var_name};
}

sub _get {
    my ($self, %matches_hash) = @_;

    my $account_id = $self->_session->get_parameter(name => 'account_id');

    if ($self->_require_auth and not defined $account_id) {
        Eve::Exception::Http::401Unauthorized->throw();
    }

    if ($self->_require_language and defined $account_id) {
        my $language_list =
            $self->_content_model->get_language_list_by_account_id(
                account_id => $account_id,
                current_account_id => $account_id);

        if (not @{$language_list}) {
            Eve::Exception::Data::LanguageNotSet->throw(
                message => 'At least one language must be set.');
        }
    }

    my $output = $self->_template->process(
        file => $self->_template_file,
        var_hash => {
            %{$self->_template_var_hash},
            'get_text' => sub {
                return $self->get_text(
                    $self->_default_language_id,
                    $self->_template_file,
                    @_);
            },
            'session' => $self->_session,
            'dispatcher' => $self->_dispatcher,
            'request' => $self->_request,
            'matches_hash' => \%matches_hash});

    if (defined $self->_content_type) {
        $self->_response->set_header(
            name => 'Content-type',
            value => $self->_content_type);
    }
    if (defined $self->_charset) {
        $self->_response->set_header(
            name => 'charset',
            value => $self->_charset);
    }
    $self->_response->set_body(text => $output);

    return;
}

=head1 SEE ALSO

=over 4

=item C<Eve::HttpDispatcher>

=item C<Eve::HttpResource>

=item C<Eve::Template>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Igor Zinovyev.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=head1 AUTHOR

=over 4

=item L<Igor Zinovyev|mailto:zinigor@gmail.com>

=back

=cut

1;
