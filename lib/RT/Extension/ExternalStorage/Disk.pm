use 5.008003;
use warnings;
use strict;

package RT::Extension::ExternalStorage::Disk;

use File::Path qw//;

use Role::Basic qw/with/;
with 'RT::Extension::ExternalStorage::Backend';

sub Init {
    my $self = shift;

    my %self = %{$self};
    if (not $self{Path}) {
        RT->Logger->error("No path provided for local storage");
        return;
    } elsif (not -e $self{Path}) {
        RT->Logger->error("Path provided for local storage ($self{Path}) does not exist");
        return;
    } elsif ($self{Write} and not -w $self{Path}) {
        RT->Logger->error("Path provided for local storage ($self{Path}) is not writable");
        return;
    }

    return $self;
}

sub Get {
    my $self = shift;
    my ($sha) = @_;

    $sha =~ m{^(...)(...)(.*)};
    my $path = $self->{Path} . "/$1/$2/$3";

    return (undef, "File does not exist") unless -e $path;

    open(my $fh, "<", $path) or return (undef, "Cannot read file on disk: $!");
    my $content = do {local $/; <$fh>};
    $content = "" unless defined $content;
    close $fh;

    return ($content);
}

sub Store {
    my $self = shift;
    my ($sha, $content) = @_;

    $sha =~ m{^(...)(...)(.*)};
    my $dir  = $self->{Path} . "/$1/$2";
    my $path = "$dir/$3";

    return (1) if -f $path;

    File::Path::make_path($dir, {error => \my $err});
    return (undef, "Making directory failed") if @{$err};

    open( my $fh, ">:raw", $path ) or return (undef, "Cannot write file on disk: $!");
    print $fh $content or return (undef, "Cannot write file to disk: $!");
    close $fh or return (undef, "Cannot write file to disk: $!");

    return (1);
}

=head1 NAME

RT::Extension::ExternalStorage::Disk - On-disk storage of attachments

=head1 SYNOPSIS

    Set(%ExternalStorage,
        Type => 'Disk',
        Path => '/opt/rt4/var/attachments',
    );

=head1 DESCRIPTION

This storage option places attachments on disk under the given C<Path>,
uncompressed.  The files are de-duplicated when they are saved; as such,
if the same file appears in multiple transactions, only one copy will be
stored on disk.

The C<Path> must be readable by the webserver, and writable by the
C<bin/extract-attachments> script.  Because the majority of the
attachments are in the filesystem, a simple database backup is thus
incomplete.  It is B<extremely important> that I<backups include the
on-disk attachments directory>.

Files also C<must not be modified or removed>; doing so may cause
internal inconsistency.

=cut

1;
