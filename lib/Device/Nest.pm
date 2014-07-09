package Device::Nest;

use warnings;
use strict;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Device::NeurioTools ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
    new connect
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw( $EXPORT_TAGS{'all'});

BEGIN
{
  if ($^O eq "MSWin32"){
    use LWP::UserAgent;
    use JSON qw(decode_json);
    use MIME::Base64 (qw(encode_base64));
    use Data::Dumper;
  } else {
    use LWP::UserAgent;
    use JSON qw(decode_json);
    use MIME::Base64 (qw(encode_base64));
    use Data::Dumper;
  }
}


=head1 NAME

Device::Nest - Methods for wrapping the Nest API calls so that they are 
                 accessible via Perl

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

#*****************************************************************

=head1 SYNOPSIS

 This module provides a Perl interface to a Nest Thermostat via the following 
 methods:
   - new
   - connect

 Please note that in order to use this module you will require two parameters
 ($ClientID,$ClientSecret) as well as a Nest Thermostat installed in your house.

 The module is written entirely in Perl and has been developped on Raspbian Linux.

=head1 SAMPLE CODE

    use Device::Neurio;

    $my_Nest = Device::Nest->new($ClientID,$ClientSecret);

    $my_Nest->connect();
  
    undef $my_Nest;


=head2 EXPORT

 All by default.


=head1 SUBROUTINES/METHODS

=head2 new - the constructor for a Neurio object

 Creates a new instance which will be able to fetch data from a unique Neurio 
 sensor.

 my $Nest = Device::Nest->new($key,$secret,$sensor_id);

   This method accepts the following parameters:
     - $key       : unique key for the account - Required 
     - $secret    : secret key for the account - Required
     - $sensor_id : sensor ID connected to the account - Required 

 Returns a Neurio object if successful.
 Returns 0 on failure
=cut
sub new {
    my $class = shift;
    my $self;

    $self->{'ua'}           = LWP::UserAgent->new();
    $self->{'ClientID'}     = shift;
    $self->{'ClientSecret'} = shift;
    $self->{'code'}         = shift;
    
    if ((!defined $self->{'ClientID'}) || (!defined $self->{'ClientSecret'}) || (!defined $self->{'code'})) {
      print "Nest->new(): ClientID, ClientSecret and code are REQUIRED parameters.\n";
      return 0;
    }
    
    bless $self, $class;
    
    return $self;
}


#*****************************************************************

=head2 connect - open a secure connection to the Nest server

 Opens a secure connection via HTTPS to the Nest server which provides
 access to a set of API commands to access the thermostat data.

   $Nest->connect();
 
 This method accepts no parameters
 
 Returns 1 on success 
 Returns 0 on failure
=cut
sub connect {
	my $self         = shift;
	my $access_token = '';
	
    # Submit request for authentiaction token.
    my $response = $self->{'ua'}->post('https://api.home.nest.com/oauth2/access_token',
          { code          => $self->{'code'},
        	grant_type    => 'authorization_code', 
        	client_id     => $self->{'ClientID'},
        	client_secret => $self->{'ClientSecret'},
          }
        );
        
    if($response->is_success) {
      my $return = $response->content;
      $return =~ /\"access_token\":\"(.*)\"/;
      $self->{'access_token'} = $1;
      return 1;
    } else {
      print "Nest->connect(): Failed to connect.\n";
      print $response->content."\n\n";
      return 0;
    }
}


#*****************************************************************

=head2 fetch_Temperature - Fetch the current temperature reported by Nest

 Retrieves the current temperature reported by the Nest.

   $Nest->fetch_Temperature();

   This method accepts no parameters
 
 Returns a Perl data structure on success:
 Returns 0 on failure
 
=cut
sub fetch_Temperature {
    my $self = shift;
    my ($url,$response,$decoded_response);
    
    $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'access_token'};
	$response = $self->{'ua'}->get($url,"Authorization"=>"Bearer ".$self->{'access_token'});
    
    print Dumper($response);
    
    if ($response->is_success) {
      $decoded_response = decode_json($response->content);
    } else {
      print "Neurio->fetch_Last_Live(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      $decoded_response = 0;
    }
    
    return $decoded_response;
}

#*****************************************************************

=head1 AUTHOR

Kedar Warriner, C<kedar at cpan.org>

=head1 BUGS

 Please report any bugs or feature requests to C<bug-device-Nest at rt.cpan.org>
 or through the web interface at http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Device-Nest
 I will be notified, and then you'll automatically be notified of progress on 
 your bug as I make changes.


=head1 SUPPORT

 You can find documentation for this module with the perldoc command.

  perldoc Device::Nest

 You can also look for information at:

=over 5

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Device-Nest>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Device-Nest>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Device-Nest>

=item * Search CPAN

L<http://search.cpan.org/dist/Device-Nest/>

=back


=head1 ACKNOWLEDGEMENTS

 Many thanks to:
  The guys at Nest for creating the Nest Thermostat sensor and 
      developping the API.
  Everyone involved with CPAN.

=head1 LICENSE AND COPYRIGHT

 Copyright 2014 Kedar Warriner <kedar at cpan.org>.

 This program is free software; you can redistribute it and/or modify it
 under the terms of either: the GNU General Public License as published
 by the Free Software Foundation; or the Artistic License.

 See http://dev.perl.org/licenses/ for more information.


=cut

#********************************************************************
1; # End of Device::Nest - Return success to require/use statement
#********************************************************************


