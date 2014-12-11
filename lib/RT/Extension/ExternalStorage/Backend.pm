use 5.008003;
use warnings;
use strict;

package RT::Extension::ExternalStorage::Backend;

use Role::Basic;

requires 'Init';
requires 'Get';
requires 'Store';

sub new {
    my $class = shift;
    my %args = @_;

    $class = delete $args{Type};
    if (not $class) {
        RT->Logger->error("No storage engine type provided");
        return undef;
    } elsif ($class->require) {
    } else {
        my $long = "RT::Extension::ExternalStorage::$class";
        if ($long->require) {
            $class = $long;
        } else {
            RT->Logger->error("Can't load external storage engine $class: $@");
            return undef;
        }
    }

    unless ($class->DOES("RT::Extension::ExternalStorage::Backend")) {
        RT->Logger->error("External storage engine $class doesn't implement RT::Extension::ExternalStorage::Backend");
        return undef;
    }

    my $self = bless \%args, $class;
    $self->Init;
}

1;
