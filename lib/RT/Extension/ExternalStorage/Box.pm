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

=pod

=head1 NAME

RT::Extension::ExternalStorage::Box

=head1 SYNOPSIS

	Plugin('RT::Extension::ExternalStorage');

	Set(%ExternalStorage,
		Type => 'Box',
		KeyId => "box_com_key_id",
		EnterpriseId =>  'box_com_enterprise_id',
		PrivateKey => "/opt/rt4/etc/keys/private_key.pem",
		Password => "my_secret_password",
		ClientId =>  "box_com_client_id",
		ClientSecret => "box_com_client_secret");

=head1 DESCRIPTION

The C<RT::Extension::ExternalStorage::Box> package provides an interface
that allows RT to store large attachments in Box.com's file storage.  It
requires setting up a custom enterprise application at Box.com attached
to your enterprise account in order to enable creating an application
managed Box.com user for RT, and provide a JWT based access credentials
for RT.

=head1 INSTALLATION


=over

=item 1.

Install storage-box and rt-extension-externalstorage:

    cpanm Storage::Box RT::Extension::ExternalStorage

=item 2.

Signup for an account at box.

=item 3.

Login to developer.box.com or L<https://app.box.com/developers/services>

=item 4.

Click Get Started if this is your first application

=item 5.

Create a unique name for your app, for example rt-myorganization

=item 6.

Under OAuth parameters, copy C<client_id> and C<client_secret> somewhere safe for later use

=item 7.

Add a redirect uri, it must be https, but need not exist.  We won't be using it anyways.

=item 8.

Under C<Authentication Type> select C<Server Authentication (OAuth2.0 with JWT)>

=item 9.

Under Scopes, Enterprise select C<Manage app users>

=item  10.

Before you can enable Public Key Managment, under C<Settings /  Security > select C<Login verification: Require 2-step verification for unrecognized logins>

=item 11.

Go back to your app and under Public Key Management, and select C<Add Public Key>

=item 12.

Using openssl, generate a private key with password in pem format by:

	openssl genrsa -aes256 -out private_key.pem 2048

=item 13.

Using openssl, create the corresponding public key file:

	openssl rsa -pubout -in private_key.pem -out public_key.pem

=item 14.

Save your password where you put the client_id and client_secret!

=item 15.

Copy and paste your public key into the C<Public Key> box and click C<Verify> and then C<Save>, you may have to enter your F2A credentials again after this.

=item 16.

Copy the Key ID next to Public Key 1 to the same safe place you are keeping your other secrets.

=item 17.

At the bottom of the page click C<Save Applications>

=item 18.

create a directory for you private and public key in the rt4 install directory such as:

	mkdir -p /opt/rt4/etc/keys
	mv *.pem /opt/rt4/etc/keys/

=item 19.

Under C<Settings / Business Settings> find the field C<Enterprise ID> and copy that to your list of secrets.

=item 20.

Edit your RT_SiteConfig.pm file to enable the C<Box> backend using the values you've saved in a safe place:

	Plugin('RT::Extension::ExternalStorage');

	Set(%ExternalStorage,
		Type => 'Box',
		KeyId => "KEY ID FROM STEP 16",
		EnterpriseId =>  'ENTERPRISE ID FROM STEP 19',
		PrivateKey => "/opt/rt4/etc/keys/private_key.pem",
		Password => "PASSWORD FROM STEP 14",
		ClientId =>  "CLIENT ID FROM STEP 6",
		ClientSecret => "CLIENT SECRET FROM STEP 6");

=item 21.

Trial run

Assuming your private key is installed and readable by your webserver process you should now have the integration working.  Running:

	/opt/rt4/local/plugins/RT-Extension-ExternalStorage/sbin/extract-attachments

by hand should copy the large files out of the current database and migrate them to Box.com.

=item 22.

Add that script to a cron job such as:

	 0 0 * * * root /opt/rt4/local/plugins/RT-Extension-ExternalStorage/sbin/extract-attachments

=back

=head1 AUTHOR

Best Practical Solutions, LLC E<lt>modules@bestpractical.comE<gt>

=head1 BUGS

All bugs should be reported via email to

L<bug-RT-Extension-ExternalStorage@rt.cpan.org|mailto:bug-RT-Extension-ExternalStorage@rt.cpan.org>

or via the web at

L<rt.cpan.org|http://rt.cpan.org/Public/Dist/Display.html?Name=RT-Extension-ExternalStorage>.

=head1 COPYRIGHT

This extension is Copyright (C) 2009-2015 Best Practical Solutions, LLC.

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut

1;

