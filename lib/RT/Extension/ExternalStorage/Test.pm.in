use strict;
use warnings;

### after: use lib qw(@RT_LIB_PATH@);
use lib qw(/opt/rt4/local/lib /opt/rt4/lib);

package RT::Extension::ExternalStorage::Test;

=head2 RT::Extension::ExternalStorage::Test

Initialization for testing.

=cut

use base qw(RT::Test);
use File::Spec;
use File::Path 'mkpath';

sub import {
    my $class = shift;
    my %args  = @_;

    $args{'requires'} ||= [];
    if ( $args{'testing'} ) {
        unshift @{ $args{'requires'} }, 'RT::Extension::ExternalStorage';
    } else {
        $args{'testing'} = 'RT::Extension::ExternalStorage';
    }

    $class->SUPER::import( %args );
    $class->export_to_level(1);

    require RT::Extension::ExternalStorage;
}

sub attachments_dir {
    my $dir = File::Spec->catdir( RT::Test->temp_directory, qw(attachments) );
    mkpath($dir);
    return $dir;
}

sub bootstrap_more_config {
    my $self = shift;
    my ($config) = @_;

    my $dir = $self->attachments_dir;
    print $config qq|Set( %ExternalStorage, Type => 'Disk', Path => '$dir' );\n|;
}

1;
