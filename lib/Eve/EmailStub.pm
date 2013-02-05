package Eve::EmailStub;

use strict;
use warnings;

use vars qw(%ENV);

BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test'; }

use Eve::Email;

sub get_delivery {
    my @deliveries = Email::Sender::Simple->default_transport->deliveries();

    return $deliveries[$#deliveries];
}

1;
