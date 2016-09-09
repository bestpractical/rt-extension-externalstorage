# vim: ai ts=4 sts=4 et sw=4 ft=perl
# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2016 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

use 5.008003;
use warnings;
use strict;

package RT::Extension::ExternalStorage::Box;

use Role::Basic qw/with/;
with 'RT::Extension::ExternalStorage::Backend';

our ( $Box );

sub Init {
    my $self = shift;
    my %self = %{$self};
    
    if (not Storage::Box->require) {
        RT->Logger->error("Required module Storage::Box is not installed");
        return;
    } elsif (not $self{KeyId}) {
        RT->Logger->error("KeyId not provided for Box.com");
        return;
    } elsif (not $self{EnterpriseId}) {
        RT->Logger->error("EnterpriseId not provided for Box.com");
        return;
    } elsif (not $self{PrivateKey}) {
        RT->Logger->error("PrivateKey not provided for Box.com");
        return;
    } elsif (not $self{Password}) {
        RT->Logger->error("Password not provided for Box.com");
        return;
    } elsif (not $self{ClientId}) {
        RT->Logger->error("ClientId not provided for Box.com");
        return;
    } elsif (not $self{ClientSecret}) {
        RT->Logger->error("ClientSecret not provided for Box.com");
        return;
    }

    $Box = Storage::Box->new( 
        key_id => $self{KeyId},
        enterprise_id => $self{EnterpriseId},
        private_key => $self{PrivateKey},
        password => $self{Password},
        client_id => $self{ClientId},
        client_secret => $self{ClientSecret}
    );

    # the first time we run, we create a 'rt' app user at Box.com
    # this user id get stored for all future file access
    # if this id is lost, it will create a new rt user but
    # that user won't have access to any of the files!!!
    my $BoxUserId = RT->System->FirstAttribute("BoxUserId");
    my $user_id = $BoxUserId ? $BoxUserId->Content || '' : '';
    if ($user_id eq '') {
        $user_id = $Box->create_user('rt');
	RT->Logger->info("Box.com rt user id $user_id");
        RT->System->SetAttribute(
            Name => "BoxUserId",
            Description => "User ID for the Box.com rt user",
            Content => $user_id
        );
    }
    $Box->user_id($user_id);
    

    return $self;
}

sub Get {
    my ($self,$key) = @_;
    RT->Logger->info("Downloading $key");
    my $contents = $Box->download_file($key);
    $contents; 
}

sub Store {
    my ($self,$key,$content) = @_;

    RT->Logger->info("Box Storing $key");
    # we need to store the file locally for libcurl to be able to upload it
    # this is a limitation of WWW::Curl::Form module, as it lacks support
    # for the CURLFORM_BUFFER and CURLFORM_BUFFERPTR options, rather it only
    # supports CURLFORM_FILE and CURLFORM_FILENAME.  But atleast it will upload
    # large files.
    open( my $fh, ">:raw", $key ) or return (undef, "Cannot write file to disk: $!");
    print $fh $content or return (undef, "Cannot write file to disk: $!");
    close $fh or return (undef, "Cannot write file to disk: $!");
    
    RT->Logger->info("Created file $key");
    my $file = $Box->create_file($key);
    RT->Logger->info("Created file " . $file);

    unlink $key;        # delete the file so we don't litter 
    return ($file); # we return the file_id for get to get it
}

1;

