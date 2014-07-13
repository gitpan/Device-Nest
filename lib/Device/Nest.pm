package Device::Nest;

use warnings;
use strict;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Device::Nest ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.

our %EXPORT_TAGS = ( 'all' => [ qw(
    new fetch_Auth_Token fetch_Thermostat_Designation fetch_Ambient_Temperature_C 
    fetch_Target_Temperature_C fetch_Target_Temperature_high_C fetch_Target_Temperature_low_C 
    fetch_Away_Temperature_low_C fetch_Ambient_Temperature_F fetch_Away_Temperature_low_F 
    fetch_Away_Temperature_high_F fetch_Target_Temperature_low_F fetch_Target_Temperature_F 
    fetch_Target_Temperature_high_F fetch_Temperature_Scale fetch_Locale fetch_Name 
    fetch_Long_Name fetch_HVAC_Mode fetch_SW_Version
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw( $EXPORT_TAGS{'all'});

BEGIN
{
  if ($^O eq "MSWin32"){
    use LWP::UserAgent;
    use JSON qw(decode_json);
    use Data::Dumper;
  } else {
    use LWP::UserAgent;
    use JSON qw(decode_json);
    use Data::Dumper;
  }
}


=head1 NAME

Device::Nest - Methods for wrapping the Nest API calls so that they are 
               accessible via Perl

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';

#*****************************************************************

=head1 SYNOPSIS

 This module provides a Perl interface to a Nest Thermostat via the following 
 methods:
   - new
   - connect
   - fetch_Ambient_Temperature
   - fetch_Designation

 In order to use this module, you will require a Nest thermostat installed in 
 your home as well.  You will also need your ClientID and ClientSecret provided
 by Nest when you register as a developper at https://developer.nest.com.  
 You will aos need an access code which can be obtained at 
 https://home.nest.com/login/oauth2?client_id=CLIENT_ID&state=FOO
 Your authorization code will be obtained and stored in this module when you
 call it.

 The module is written entirely in Perl and has been developped on Raspbian Linux.

=head1 SAMPLE CODE

    use Device::Nest;

    $my_Nest = Device::Nest->new($ClientID,$ClientSecret,$code,$phrase);

    $my_Nest->connect();
  
    undef $my_Nest;


 You need to get an authorization code by going to https://home.nest.com/login/oauth2?client_id=CLIENT_ID&state=FOO
 and specifying your client ID in the URL along with a random string for state
 
 Use this code, along with your ClientID and ClientSecret to get an authorization code
 by using the 'connect' function below.  
 
 From now on, all you need is your auth_token
 


=head2 EXPORT

 All by default.


=head1 SUBROUTINES/METHODS

=head2 new - the constructor for a Nest object

 Creates a new instance which will be able to fetch data from a unique Nest 
 sensor.

 my $Nest = Device::Nest->new($ClientID,$ClientSecret,$phrase);

   This method accepts the following parameters:
     - $ClientID     : Client ID for the account - Required 
     - $ClientSecret : Secret key for the account - Required
     - $auth_token   : authentication token to access the account - Required 

 Returns a Nest object if successful.
 Returns 0 on failure
=cut
sub new {
    my $class = shift;
    my $self;
    
    $self->{'ua'}            = LWP::UserAgent->new();
    $self->{'ClientID'}      = shift;
    $self->{'ClientSecret'}  = shift;
    $self->{'PIN_code'}      = shift;
    $self->{'auth_token'}    = shift;
    
    if ((!defined $self->{'ClientID'}) || (!defined $self->{'ClientSecret'}) || (!defined $self->{'PIN_code'}) || (!defined $self->{'auth_token'})) {
      print "Nest->new(): ClientID, ClientSecret, PIN_code and auth_token are REQUIRED parameters.\n";
      return 0;
    }
    
    bless $self, $class;
    
    return $self;
}


#*****************************************************************

=head2 fetch_Auth_Token - generates and displays the auth_token 

 This function will display the authenticaton token for the PIN code
 provided.  This can only be done once per PIN code.  Pleas make sure
 to note and store your auth code since it will be the only thing requiired
 for all other API calls.

   $Nest->fetch_Auth_Token();
 
 This method accepts no parameters
 
 Returns 1 on success and prints auth_token
 Returns 0 on failure
=cut
sub fetch_Auth_Token {
	my $self       = shift;
	my $auth_token = '';
	
    # Submit request for authentiaction token.
    my $response = $self->{'ua'}->post('https://api.home.nest.com/oauth2/access_token',
          { code          => $self->{'PIN_code'},
        	grant_type    => 'authorization_code', 
        	client_id     => $self->{'ClientID'},
        	client_secret => $self->{'ClientSecret'},
          }
        );
    
    if($response->is_success) {
      if ($response->content =~ /\"access_token\":\"(.*?)\"/) {
      	print "Found authentication code.  Please use it when calling functions\n";
      	print "Authentication code: $1\n";
      	return 1;
      } else {
        print "No authentication token found.\n";
        print "Make sure your PIN is correct.\n";
        print "You may need to request a new PIN\n";
        return 0;
      }
    } else {
      print "No authentication token found.\n";
      print "Make sure your PIN is correct.\n";
      print "You may need to request a new PIN\n";
      return 0;
    }
}


#*****************************************************************

=head2 fetch_Thermostat_Designation - fetch the designation for your thermostat

 Retrieves the code designating your thermostat and stores it in $self

   $Nest->fetch_Thermostat_Designation();

   This method accepts no parameters
 
 Returns 1 on success
 Returns 0 on failure
 
=cut
sub fetch_Thermostat_Designation {
    my $self     = shift;
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response  = decode_json($response->content);
      my $designation       = ($decoded_response->{'thermostats'});
      my @designation2      = keys(%$designation);
      $self->{'thermostat'} = $designation2[0];
      return 1;
    } else {
      print "Nest->fetch_Thermostat_Designation(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}


#*****************************************************************

=head2 fetch_Ambient_Temperature_C - Fetch the ambient temperature reported by Nest in Celcius

 Retrieves the ambient temperature reported by the Nest in Celcius

   $Nest->fetch_Ambient_Temperature_C();

   This method accepts no parameters
 
 Returns the ambient temperature in Celcius
 Returns 0 on failure
 
=cut
sub fetch_Ambient_Temperature_C {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'ambient_temperature_c'};
    } else {
      print "Nest->fetch_Ambient_Temperature_C(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}

#*****************************************************************

=head2 fetch_Target_Temperature_C - Fetch the target temperature reported by Nest in Celcius

 Retrieves the target temperature reported by the Nest in Celcius

   $Nest->fetch_Target_Temperature_C();

   This method accepts no parameters
 
 Returns the target temperature in Celcius
 Returns 0 on failure
 
=cut
sub fetch_Target_Temperature_C {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'target_temperature_c'};
    } else {
      print "Nest->fetch_Target_Temperature_C(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}

#*****************************************************************

=head2 fetch_Target_Temperature_high_C - Fetch the higher target temperature reported by Nest in Celcius

 Retrieves the high target temperature reported by the Nest in Celcius

   $Nest->fetch_Target_Temperature_high_C();

   This method accepts no parameters
 
 Returns the high target temperature in Celcius
 Returns 0 on failure
 
=cut
sub fetch_Target_Temperature_high_C {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'target_temperature_high_c'};
    } else {
      print "Nest->fetch_Target_Temperature_high_C(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}

#*****************************************************************

=head2 fetch_Target_Temperature_low_C - Fetch the lower target temperature reported by Nest in Celcius

 Retrieves the lower target temperature reported by the Nest in Celcius

   $Nest->fetch_Target_Temperature_low_C();

   This method accepts no parameters
 
 Returns the lower target temperature in Celcius
 Returns 0 on failure
 
=cut
sub fetch_Target_Temperature_low_C {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'target_temperature_low_c'};
    } else {
      print "Nest->fetch_Target_Temperature_low_C(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}

#*****************************************************************

=head2 fetch_Away_Temperature_low_C - Fetch the lower away temperature reported by Nest in Celcius

 Retrieves the lower away temperature reported by the Nest in Celcius

   $Nest->fetch_Away_Temperature_low_C();

   This method accepts no parameters
 
 Returns the lower away temperature in Celcius
 Returns 0 on failure
 
=cut
sub fetch_Away_Temperature_low_C {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'away_temperature_low_c'};
    } else {
      print "Nest->fetch_Away_Temperature_low_C(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}

#*****************************************************************

=head2 fetch_Away_Temperature_high_C - Fetch the high away temperature reported by Nest in Celcius

 Retrieves the high away temperature reported by the Nest in Celcius

   $Nest->fetch_Away_Temperature_high_C();

   This method accepts no parameters
 
 Returns the high away temperature in Celcius
 Returns 0 on failure
 
=cut
sub fetch_Away_Temperature_high_C {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'away_temperature_high_c'};
    } else {
      print "Nest->fetch_Away_Temperature_high_C(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}

#*****************************************************************

=head2 fetch_Ambient_Temperature_F - Fetch the ambient temperature reported by Nest in Fahrenheit

 Retrieves the ambient temperature reported by the Nest in Fahrenheit

   $Nest->fetch_Ambient_Temperature_F();

   This method accepts no parameters
 
 Returns the ambient temperature in Fahrenheit
 Returns 0 on failure
 
=cut
sub fetch_Ambient_Temperature_F {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'ambient_temperature_f'};
    } else {
      print "Nest->fetch_Ambient_Temperature_F(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}

#*****************************************************************

=head2 fetch_Away_Temperature_low_F - Fetch the lower away temperature reported by Nest in Fahrenheit

 Retrieves the lower away temperature reported by the Nest in Fahrenheit

   $Nest->fetch_Away_Temperature_low_F();

   This method accepts no parameters
 
 Returns the lower away temperature in Fahrenheit
 Returns 0 on failure
 
=cut
sub fetch_Away_Temperature_low_F {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'away_temperature_low_f'};
    } else {
      print "Nest->fetch_Away_Temperature_low_F(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}

#*****************************************************************

=head2 fetch_Away_Temperature_high_F - Fetch the higher away temperature reported by Nest in Fahrenheit

 Retrieves the higher away temperature reported by the Nest in Fahrenheit

   $Nest->fetch_Away_Temperature_high_F();

   This method accepts no parameters
 
 Returns the higher away temperature in Fahrenheit
 Returns 0 on failure
 
=cut
sub fetch_Away_Temperature_high_F {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'away_temperature_high_f'};
    } else {
      print "Nest->fetch_Away_Temperature_high_F(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}

#*****************************************************************

=head2 fetch_Target_Temperature_low_F - Fetch the lower target temperature reported by Nest in Fahrenheit

 Retrieves the lower target temperature reported by the Nest in Fahrenheit

   $Nest->fetch_Target_Temperature_low_F();

   This method accepts no parameters
 
 Returns the lower target temperature in Fahrenheit
 Returns 0 on failure
 
=cut
sub fetch_Target_Temperature_low_F {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'target_temperature_low_f'};
    } else {
      print "Nest->fetch_Target_Temperature_low_F(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}

#*****************************************************************

=head2 fetch_Target_Temperature_F - Fetch the target temperature reported by Nest in Fahrenheit

 Retrieves the target temperature reported by the Nest in Fahrenheit

   $Nest->fetch_Target_Temperature_F();

   This method accepts no parameters
 
 Returns the target temperature in Fahrenheit
 Returns 0 on failure
 
=cut
sub fetch_Target_Temperature_F {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'target_temperature_f'};
    } else {
      print "Nest->fetch_Target_Temperature_F(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}

#*****************************************************************

=head2 fetch_Target_Temperature_high_F - Fetch the higher target temperature reported by Nest in Fahrenheit

 Retrieves the higher target temperature reported by the Nest in Fahrenheit

   $Nest->fetch_Target_Temperature_high_F();

   This method accepts no parameters
 
 Returns the target temperature in Fahrenheit
 Returns 0 on failure
 
=cut
sub fetch_Target_Temperature_high_F {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'target_temperature_high_f'};
    } else {
      print "Nest->fetch_Target_Temperature_high_F(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}

#*****************************************************************

=head2 fetch_Temperature_Scale - Fetch the temperature scale reported by Nest

 Retrieves the temperature scale reported by the Nest as either F (Fahrenheit)
 or C (Celcius)

   $Nest->fetch_Temperature_Scale();

   This method accepts no parameters
 
 Returns the temperature scale
 Returns 0 on failure
 
=cut
sub fetch_Temperature_Scale {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'temperature_scale'};
    } else {
      print "Nest->fetch_Temperature_Scale(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}


#*****************************************************************

=head2 fetch_Locale - Fetch the locale reported by Nest

 Retrieves the locale reported by the Nest 

   $Nest->fetch_Locale();

   This method accepts no parameters
 
 Returns the locale
 Returns 0 on failure
 
=cut
sub fetch_Locale {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'locale'};
    } else {
      print "Nest->fetch_Locale(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}

#*****************************************************************

=head2 fetch_Name - Fetch the name reported by Nest

 Retrieves the name reported by the Nest 

   $Nest->fetch_Name();

   This method accepts no parameters
 
 Returns the name of the thermostat
 Returns 0 on failure
 
=cut
sub fetch_Name {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'name'};
    } else {
      print "Nest->fetch_Name(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}


#*****************************************************************

=head2 fetch_Long_Name - Fetch the long name reported by Nest

 Retrieves the long name reported by the Nest 

   $Nest->fetch_Long_Name();

   This method accepts no parameters
 
 Returns the long name of the thermostat
 Returns 0 on failure
 
=cut
sub fetch_Long_Name {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'name_long'};
    } else {
      print "Nest->fetch_Long_Name(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}


#*****************************************************************

=head2 fetch_HVAC_Mode - Fetch the HVAC Mode reported by Nest

 Retrieves the HVAC Mode reported by the Nest as either 'heat' or 'cool'

   $Nest->fetch_HVAC_Mode();

   This method accepts no parameters
 
 Returns the HVAC mode
 Returns 0 on failure
 
=cut
sub fetch_HVAC_Mode {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'hvac_mode'};
    } else {
      print "Nest->fetch_HVAC_Mode(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
}


#*****************************************************************

=head2 fetch_SW_Version - Fetch the software version reported by Nest

 Retrieves the software version reported by the Nest

   $Nest->fetch_SW_Version();

   This method accepts no parameters
 
 Returns the software version
 Returns 0 on failure
 
=cut
sub fetch_SW_Version {
    my $self = shift;
    
    if (!defined $self->{'thermostat'}) {
      print "No thermostat designation found\n";
      return 0;
    }
    
    my $url      = "https://developer-api.nest.com/devices.json?auth=".$self->{'auth_token'};
	my $response = $self->{'ua'}->get($url);
    
    if ($response->is_success) {
      my $decoded_response = decode_json($response->content);
      return $decoded_response->{'thermostats'}->{$self->{'thermostat'}}->{'software_version'};
    } else {
      print "Nest->fetch_SW_Version(): Response from server is not valid\n";
      print "  \"".$response->content."\"\n\n";
      return 0;
    }
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


