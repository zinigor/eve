package Eve::PsgiStub;

use strict;
use warnings;

use Eve::RegistryStub;

use Eve::HttpRequest::Psgi;
use Eve::Registry;

sub get_request {
    my ($self, %arg_hash) = @_;
    Eve::Support::arguments(
        \%arg_hash,
        my $uri = '/',
        my $host = 'example.localhost',
        my $query = '',
        my $method = 'GET',
        my $body = '',
        my $cookie = '',
        my $content_type = \undef);

    my $env_hash = {
        'psgi.multiprocess' => 1,
        'SCRIPT_NAME' => '',
        'PATH_INFO' => $uri,
        'HTTP_ACCEPT' =>
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'REQUEST_METHOD' => $method,
        'psgi.multithread' => '',
        'SCRIPT_FILENAME' => '/var/www/some/path',
        'SERVER_SOFTWARE' => 'Apache/2.2.20 (Ubuntu)',
        'HTTP_USER_AGENT' => 'Mozilla/5.0 Gecko/20100101 Firefox/9.0.1',
        'REMOTE_PORT' => '53427',
        'QUERY_STRING' => $query,
        'SERVER_SIGNATURE' => '<address>Apache/2.2.20 Port 80</address>',
        'HTTP_CACHE_CONTROL' => 'max-age=0',
        'HTTP_ACCEPT_LANGUAGE' => 'en-us,en;q=0.7,ru;q=0.3',
        'HTTP_X_REAL_IP' => '127.0.0.1',
        'psgi.streaming' => 1,
        'MOD_PERL_API_VERSION' => 2,
        'PATH' => '/usr/local/bin:/usr/bin:/bin',
        'GATEWAY_INTERFACE' => 'CGI/1.1',
        'psgi.version' => [ 1, 1 ],
        'DOCUMENT_ROOT' => '/var/www/some/other/path',
        'psgi.run_once' => '',
        'SERVER_NAME' => $host,
        'SERVER_ADMIN' => '[no address given]',
        'HTTP_ACCEPT_ENCODING' => 'gzip, deflate',
        'HTTP_CONNECTION' => 'close',
        'HTTP_ACCEPT_CHARSET' => 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
        'SERVER_PORT' => '80',
        'HTTP_COOKIE' => $cookie,
        'REMOTE_ADDR' => '127.0.0.1',
        'SERVER_PROTOCOL' => 'HTTP/1.0',
        'HTTP_X_FORWARDED_FOR' => '127.0.0.1',
        'psgi.errors' => *STDERR,
        'REQUEST_URI' => $uri . (length $query ? '?' . $query : ''),
        'psgi.nonblocking' => '',
        'SERVER_ADDR' => '127.0.0.1',
        'psgi.url_scheme' => 'http',
        'HTTP_HOST' => $host,
        'psgi.input' =>
            bless( do{ \ (my $o = '140160744829088')}, 'Apache2::RequestRec'),
        'MOD_PERL' => 'mod_perl/2.0.5'};

    if ($method eq 'POST' and defined $body and length $body) {
        $env_hash = {
            %{$env_hash},
            'CONTENT_LENGTH' => length $body,
            'CONTENT_TYPE' =>
                'application/x-www-form-urlencoded; charset=UTF-8',
            'psgix.input.buffered' => 1,
            'psgi.input' => FileHandle->new(\ $body, '<')};
    }

    if (defined $content_type) {
        $env_hash = {
            %{$env_hash},
            'CONTENT_TYPE' => $content_type . '; charset=UTF-8'};
    }

    my $registry = Eve::Registry->new();

    return Eve::HttpRequest::Psgi->new(
        uri_constructor => sub {
            return $registry->get_uri(@_);
        },
        env_hash => $env_hash);
}

1;
