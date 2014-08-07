###########################################
# FHEMduino Oregon Scienfific Modul (Remote Weather sensor)
# $Id: 14_FHEMduino_Oregon.pm 0001 2014-06-25 sidey $
# Based on 41_Oregon.pm from Willi Herzig (Willi.Herzig@gmail.com)
##############################################
package main;

use strict;
use warnings;
use Data::Dumper;

#require 41_Oregon;
# TODO
# 
# * reset last reading einbauen

#####################################
sub FHEMduino_Oregon_Initialize($)
{
# Jörg: Es fehlte das _Orgegon_

  my ($hash) = @_;

#					  9ADC539970205024
#					  EA4C10E45016D083
  # output format is "AAAACRRBTTTS"
  #                   
  # AAAA = Sensor Type on V2.1  **AA on V2.2   Nibble 0-3
  #   C = Channel							   Nibble 4
  #  RR = Rolling ID						   Nibble 5-6
  #   B = Battery							   Nibble 7
  #  TTT = Temperature in BCD Code			   Nibble 8-10
  #   S = Sign								   Nibble 11
  

  $hash->{Match}     = "^OSV.*";
  $hash->{DefFn}     = "FHEMduino_Oregon_Define";
  $hash->{UndefFn}   = "FHEMduino_Oregon_Undef";
  $hash->{AttrFn}    = "FHEMduino_Oregon_Attr";
  $hash->{ParseFn}   = "FHEMduino_Oregon_Parse";
  $hash->{AttrList}  = "IODev do_not_notify:0,1 showtime:0,1 ignore:0,1 ".$readingFnAttributes;
#  $hash->{AutoCreate}=
#        { "FHEMduino_Oregon.*" => { GPLOT => "temp4hum4:Temp/Hum,", FILTER => "%NAME" } };

}


#####################################
sub FHEMduino_Oregon_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  return "wrong syntax: define <name> FHEMduino_Oregon <code>".int(@a)
  		if(int(@a) < 3 || int(@a) > 5);

  $hash->{CODE}    = $a[2];
  $hash->{minsecs} = ((int(@a) > 3) ? $a[3] : 0);
  $hash->{equalMSG} = ((int(@a) > 4) ? $a[4] : 0);
  $hash->{lastMSG} =  "";

  $modules{FHEMduino_Oregon}{defptr}{$a[2]} = $hash;
  $hash->{STATE} = "Defined";
  AssignIoPort($hash);
  return undef;
}

#####################################
sub FHEMduino_Oregon_Undef($$)
{
  my ($hash, $name) = @_;
  delete($modules{FHEMduino_Oregon}{defptr}{$hash->{CODE}}) if($hash && $hash->{CODE});
  return undef;
}

#########################################
# From xpl-perl/lib/xPL/Util.pm:
sub FHEMduino_Oregon_hi_nibble {
  ($_[0]&0xf0)>>4;
}
sub FHEMduino_Oregon_lo_nibble {
  $_[0]&0xf;
}

#sub FHEMduino_Oregon_nibble_sum {
#  my $c = $_[0];
#  my $s = 0;
#  foreach (0..$_[0]-1) {
#    $s += OREGON_hi_nibble($_[1]->[$_]);
#    $s += OREGON_lo_nibble($_[1]->[$_]);
#  }
#  $s += OREGON_hi_nibble($_[1]->[$_[0]]) if (int($_[0]) != $_[0]);
#  return $s;
#}
# --------------------------------------------
# The following functions are changed:
#	- some parameter like "parent" and others are removed
#	- @res array return the values directly (no usage of xPL::Message)

my $DOT = q{_};

# Test if to use longid for device type
sub FHEMduino_Oregon_use_longid {
  my ($longids,$dev_type) = @_;

  return 0 if ($longids eq "");
  return 0 if ($longids eq "NONE");
  return 0 if ($longids eq "0");

  return 1 if ($longids eq "1");
  return 1 if ($longids eq "ALL");

  return 1 if(",$longids," =~ m/,$dev_type,/);

  return 0;
}

sub FHEMduino_Oregon_simple_battery {
  my ($bytes, $dev, $res) = @_;
  my $battery_low = $bytes->[4]&0x4;
  #my $bat = $battery_low ? 10 : 90;
  my $battery = $battery_low ? "low" : "ok";
  push @$res, {
		device => $dev,
		type => 'battery',
		current => $battery,
		units => '%',
	}
}


sub FHEMduino_Oregon_common_temp {
  my ($type, $longids, $bytes) = @_;
  
  
  #print "common_temp bytes:".Dumper($bytes);
  my $device = sprintf "%02x", $bytes->[3];
  #my $dev_str = $type.$DOT.$device;
  my $dev_str = $type;
  if (FHEMduino_Oregon_use_longid($longids,$type)) {
  	$dev_str .= $DOT.sprintf("%02x", $bytes->[3]);
  }
  if (FHEMduino_Oregon_hi_nibble($bytes->[2]) > 0) {
  	$dev_str .= $DOT.sprintf("%d", FHEMduino_Oregon_hi_nibble($bytes->[2]));
  }

  my @res = ();
  FHEMduino_Oregon_temperature($bytes, $dev_str, \@res);
  FHEMduino_Oregon_simple_battery($bytes, $dev_str, \@res);
  return @res;
}

sub FHEMduino_Oregon_temperature {
  my ($bytes, $dev, $res) = @_;

  my $temp =
    (($bytes->[6]&0x8) ? -1 : 1) *
      (FHEMduino_Oregon_hi_nibble($bytes->[5])*10 + FHEMduino_Oregon_lo_nibble($bytes->[5]) +
       FHEMduino_Oregon_hi_nibble($bytes->[4])/10);

  push @$res, {
       		device => $dev,
       		type => 'temp',
       		current => $temp,
		units => 'Grad Celsius'
       } 
}

sub  FHEMduino_Oregon_percentage_battery {
  my ($nibble, $dev, $res) = @_;

  my $battery;
  my $battery_level;
  $battery_level = 100-10*$nibble->[7];
  if ($battery_level > 50) {
    $battery = sprintf("ok %d%%",$battery_level);
  } else {
    $battery = sprintf("low %d%%",$battery_level);
  }

  push @$res, {
		device => $dev,
		type => 'battery',
		current => $battery,
		units => '%',
	}
	  

}
	
#####################################
sub FHEMduino_Oregon_Parse($$)
{
  
  my ($hash,$msg) = @_;
  my $deviceCode; 

  my $longids = 1;
  if (defined($attr{$hash->{NAME}}{longids})) {
  	$longids = $attr{$hash->{NAME}}{longids};
  	Log 3,"0: attr longids = $longids";
  }


  #print "Orig msg:".Dumper($msg);
  my $hex_msg = substr $msg, 5;
  #print "Hex msg:".Dumper($hex_msg);
  
  my @a = unpack("(A2)*", );
  # convert to binary
  my $bin_msg = pack('H*', substr $msg, 5);
  #print "Bin msg:".Dumper($bin_msg);
  
  # convert string to array of bytes. 
  my @data_array = ();
  foreach (split(//, $bin_msg)) {
    push (@data_array, ord($_) );
  }

  
  my $bits = ord($bin_msg);
  my $num_bytes = $bits >> 3; if (($bits & 0x7) != 0) { $num_bytes++; }

  my $type1 = $data_array[0];
  my $type2 = $data_array[1];
	
  my $type = ($type1 << 8) + $type2;

  my $sensor_id = unpack('H*', chr $type1) . unpack('H*', chr $type2);
  Log 1, "FHEMduino_Oregon: sensor_id=$sensor_id";  
  
  #print "Type:".Dumper($type);
  #print "Type1:".Dumper($type1);
  #print "Type2:".Dumper($type2);
  #print Dumper($a[1]);

  
  if ( $type2 == 220)  ##220=DC(hex)
  {
    $deviceCode = unpack('H*', chr $type2); #type1 ist ein rollierender code
  } else {
    $deviceCode = $sensor_id
  }
  
  my $def = $modules{FHEMduino_Oregon}{defptr}{$hash->{NAME} . "." . $deviceCode};
  $def = $modules{FHEMduino_Oregon}{defptr}{$deviceCode} if(!$def);
  if(!$def) {
    Log3 $hash, 1, "FHEMduino_Oregon UNDEFINED sensor detected, code $deviceCode";
    return "UNDEFINED FHEMduino_Oregon_$deviceCode FHEMduino_Oregon $deviceCode";
  }
  
  $hash = $def;
  my $name = $hash->{NAME};
  return "" if(IsIgnored($name));
  
  Log3 $name, 3, "FHEMduino_Oregon $name ($msg)";  

  if($hash->{lastReceive} && (time() - $hash->{lastReceive} < $def->{minsecs} )) {
    if (($def->{lastMSG} ne $msg) && ($def->{equalMSG} > 0)) {
      Log3 $name, 4, "FHEMduino_Oregon $name: $deviceCode no skipping due unequal message even if to short timedifference";
    } else {
      Log3 $name, 4, "FHEMduino_Oregon $name: $deviceCode Skipping due to short timedifference";
      return "";
    }
  }
  
  
  # Prüfen ob der Datenstrom groß genug ist
 if (scalar(@data_array) < 7)
 {
   Log3 $name, 4, "FHEMduino_Oregon $name: $deviceCode Skipping code is to short $msg";
       return "FHEMduino_Oregon $name: $deviceCode Skipping code is to short $msg";
 }
  my %device_data;
  
  my @res = ();
 
 #my $part= "THN132N";
 my $part= $sensor_id;
 #print Dumper(@data_array);

 my $ref = \@data_array;
 #print "Referenz:".Dumper($ref->[1]);
 @res=FHEMduino_Oregon_common_temp($part,$longids,\@data_array);
 
 #print Dumper(@res);
  $hash->{lastReceive} = time();
  #$hash->{lastValues}{temperature} = $tmp;
  #$hash->{lastValues}{humidity} = $hum;
  $def->{lastMSG} = $msg;

 
  #if(!$device_data) {
  #  Log3 $name, 1, "FHEMduino_Oregon $deviceCode Cannot decode $msg";
  #  return "";
  #}
  #if ($hash->{lastReceive} && (time() - $hash->{lastReceive} < 300)) {
  # if ($hash->{lastValues} && (abs(abs($hash->{lastValues}{temperature}) - abs($tmp)) > 5)) {
  #
  # Log3 $name, 1, "FHEMduino_Oregon $deviceCode Temperature jump too large";
  #    return "";
  #  }


  #  if ($hash->{lastValues} && (abs(abs($hash->{lastValues}{humidity}) - abs($hum)) > 5)) {
  #    Log3 $name, 1, "FHEMduino_Oregon $deviceCode Humidity jump too large";
  #    return "";
  #  }
  #}
  #else {
  #  Log3 $name, 1, "FHEMduino_Oregon $deviceCode Skipping override due to too large timedifference";
  #}
  $hash->{lastReceive} = time();
  #$hash->{lastValues}{temperature} = $tmp;
  #$hash->{lastValues}{humidity} = $hum;

  my $i;
  my $val = "";
  
  readingsBeginUpdate($hash);

  foreach $i (@res){
	if ($i->{type} eq "temp") { 
			$val .= "T: ".$i->{current}." ";
			readingsBulkUpdate($hash, "state", $val);
			readingsBulkUpdate($hash, "temperature", $i->{current});
  	} 
	elsif ($i->{type} eq "battery") { 
			my @words = split(/\s+/,$i->{current});
			$val .= "BAT: ".$words[0]." "; #use only first word
			readingsBulkUpdate($hash, "battery", $val);
  	} 

	}
#  Log3 $name, 4, "FHEMduino_Oregon $name: $val";
   
#  readingsBeginUpdate($hash);
#  readingsBulkUpdate($hash, "state", $val);
#  readingsBulkUpdate($hash, "temperature", $res[0]=>'current');
#  readingsBulkUpdate($hash, "humidity", $hum);
#  readingsBulkUpdate($hash, "battery", $bat);
#  readingsBulkUpdate($hash, "trend", $trend);
#  readingsBulkUpdate($hash, "sendMode", $sendMode);
  readingsEndUpdate($hash, 1); # Notify is done by Dispatch

  return $name;
}

sub FHEMduino_Oregon_Attr(@)
{
  my @a = @_;

  # Make possible to use the same code for different logical devices when they
  # are received through different physical devices.
  return if($a[0] ne "set" || $a[2] ne "IODev");
  my $hash = $defs{$a[1]};
  my $iohash = $defs{$a[3]};
  my $cde = $hash->{CODE};
  delete($modules{FHEMduino_Oregon}{defptr}{$cde});
  $modules{FHEMduino_Oregon}{defptr}{$iohash->{NAME} . "." . $cde} = $hash;
  return undef;
}


1;

=pod
=begin html

<a name="FHEMduino_Oregon"></a>
<h3>FHEMduino_Oregon</h3>
<ul>
  The FHEMduino_Oregon module interprets Oregon Scientific Data of messages received by the FHEMduino.
  <br><br>

  <a name="FHEMduino_Oregondefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; FHEMduino_Oregon &lt;code&gt; [minsecs] [equalmsg]</code> <br>
    <br>
 
    &lt;code&gt; ist der sensor ID Code des Snesors und besteht aus der
	Sensor ID + Kanalnumme (1..5) <br>
    minsecs definert die Sekunden die mindesten vergangen sein müssen bis ein neuer
	Logeintrag oder eine neue Nachricht generiert werden.
    <br>
	Z.B. wenn 300, werden Einträge nur alle 5 Minuten erzeugt, auch wenn das Device
    alle paar Sekunden eine Nachricht generiert. (Reduziert die Log-Dateigröße und die Zeit
	die zur Anzeige von Plots benötigt wird.)<br>
	equalmsg gesetzt auf 1 legt fest, dass Einträge auch dann erzeugt werden wenn die durch
	minsecs vorgegebene Zeit noch nicht verstrichen ist, sich aber der Nachrichteninhalt geändert
	hat.
	</ul>
  <br>

  <a name="FHEMduino_Oregonset"></a>
  <b>Set</b> <ul>N/A</ul><br>

  <a name="FHEMduino_Oregonget"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a name="FHEMduino_Oregonattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#IODev">IODev (!)</a></li>
    <li><a href="#do_not_notify">do_not_notify</a></li>
    <li><a href="#eventMap">eventMap</a></li>
    <li><a href="#ignore">ignore</a></li>
    <li><a href="#model">model</a> </li>
    <li><a href="#showtime">showtime</a></li>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
  </ul>
  <br>
</ul>

=end html
=cut