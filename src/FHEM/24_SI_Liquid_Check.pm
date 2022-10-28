########################################################################################
# $Id: 24_SI_Liquid_Check.pm 001 2017-10-25 07:14:53 rm $
# updated 27.10.2022 for Liquid-Check SM1 
#
#  (c) 2017 Copyright: SI-Elektronik GmbH, Ronald Malkmus
#  e-mail: liquid-check at si-elektronik dot de
#
########################################################################################
#
#  This programm is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  You should have received a copy of the GNU General Public License
#  along with fhem.  If not, see <http://www.gnu.org/licenses/>.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
########################################################################################
#  Description:
#  This is an FHEM-Module for the SI-Elektronik GmbH Level-Sensor 'SI_Liquid_Check'
#  SI_Liquid_Check is a wifi controlled Level-Sensor for Water tanks or other liquids.
#  The measuring method is based on a hydrostatic measurement of the filling level
#  It support reading of Fluid_Level, Fluid_Volume
#
#  Automatic find the sensor device at local Network in blocking receive mode
#  with a variable timeout setting (default 1sec).	
#  Periodic sensor query in non-blocking receive mode
#  Polling interval between 10 - 86400 Sec. (default 300 sec.)
#
#
#   Vers. 1.5   Einlesen der Raw Werte measure.raw.content, measure.raw.level
#				Commandref aktualisiert
#
#	Vers. 1.4   Erweiterung Liquid-Check SM1 mit Schaltplatine 
#				Temp.Sensor und Relais-Zustand auslesen
#
#	Vers. 1.3   getSensor auskommentiert in "SI_Liquid_Check_Read" 
#				und Timer neu starten. Bug (Abruf bleibt stehen) beseitigt
#
#	Vers. 1.2   Warning Zeile 314,317 beim Start von Fhem beseitigt
#
#	Vers. 1.1	NEXTUPDATE in Readings verschoben u. angepasst
#				Neues Reading "nextupdtime", jede Readingänderung erzeugt einen Event
#				Neues Reading "last.measure.content", "last.measure.level"
#				Readings "round.measure.content" und "round.measure.level" entfernt
#				Standard State Icon geändert (ohne Überschrift)
#               SET-Befehl "messung_starten" für Messung aktivieren ergänzt
#				Neues Attribut "showTrend" für Darstellung einer Trendanzeige mit Pfeil
#				Verbesserte Aktualisierung bei Neustart
#				Hilfe aktualisiert
#				
#   Vers. 1.0   Fehlerhafte readings entfernt device.model, device.security; help mit icon-info ergänzt
#	Vers. 0.9	timeout in attributen ergänzt, Kommentare bearbeitet, debug dummy entfernt
#	Vers. 0.8	$round.level auf 0.5 Digit runden 
#	Vers. 0.7	Readings mit gerundeten Werten anlegen
#	Vers. 0.6	"Intervall" als Attribut damit bei einem Neustart gesichert
#	Vers. 0.5	Fehler für Roundlevel beseitigt / $level auf 2 Nachkommastellen gerundet
#	Vers. 0.4	Menge > 99 Liter auf ganze Liter gerundet / % Wert auf 100 begrenzen /Doku kleine Ergänzung
#	Vers. 0.3	SI-Gerät suchen : sub get_sensor_addr($) integriert
#	Vers. 0.2	Mit externem Tool SI-Gerät suchen
#
########################################################################################

package main;

use strict;
use warnings;
use JSON;
use Data::Dumper;
use HttpUtils;
use IO::Socket::INET;

# flush after every write
$| = 1;

#####################################
sub SI_Liquid_Check_Initialize($)
{
  my ($hash) = @_;
  
  $hash->{DefFn}      = "SI_Liquid_Check_Define";
  $hash->{ReadFn}     = "SI_Liquid_Check_Read";
  $hash->{SetFn}      = "SI_Liquid_Check_Set";
  $hash->{GetFn}      = "SI_Liquid_Check_Get";
  $hash->{UndefFn}    = "SI_Liquid_Check_Undefine";
  $hash->{DeleteFn}   = "SI_Liquid_Check_Delete";
  $hash->{AttrFn}     = "SI_Liquid_Check_Attr";
  $hash->{AttrList}   = "disable:0,1 " .
						"devStateIcPaNa ".
						"interval ".
						"timeout ".
						"maxInhaltLiter ".
						"showTrend:1,0 ".
                        "$readingFnAttributes";
}

#####################################
sub SI_Liquid_Check_Define($$)
{
  my ($hash, $def) = @_;
  my $name= $hash->{NAME};
  my $b_get_sensor = 0;

  my @a = split( "[ \t][ \t]*", $def );
  return "Wrong syntax: use define <name> SI_Liquid_Check <IP-Adress>\n  # IP-Adress is optional" if (int(@a) < 2);
  return "Wrong syntax: use define <name> SI_Liquid_Check <IP-Adress>\n  # IP-Adress is optional" if (int(@a) > 3);
  if(int(@a) == 3)
   {
  	if($a[2]=~ m/[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}/) 
		{$hash->{HOST}=$a[2];}
	else
		{return "Wrong syntax: use define <name> SI_Liquid_Check <IP-Adress>\n # IP-Adress is optional";}
   }	
  else 
   {
  	# Ermittelt die IP-Adresse etc. des SI-Sensors mittels Broadcast
  	# <get_sensor_addr> wird nach dem init aufgerufen
  	$b_get_sensor = 1;
   }     
  
  $hash->{INTERVAL}=300;		# Intervall in Sek. (10-86400) für des zyklische Lesen der Sensordaten
  $hash->{status}='Try to connect';
  $hash->{SENSOR}='device_name: seek';

  
  #initial request after 12 secs, later the timer is set to <Interval> for further update
  InternalTimer(gettimeofday()+12, "SI_Liquid_Check_Read", $hash, 0);


# prüfen, ob eine neue Definition angelegt wird 
  if($init_done && !defined($hash->{OLDDEF}))
   {
  	if(!defined($hash->{OLDDEF}))
	 {
		# setzen von stateFormat
	 	$attr{$name}{"devStateIcon"} = "{SI_Liquid_Check_devStateIcon(\$name)}";	#Funktion zur Übergabe StateIcon
	 	$attr{$name}{"devStateIcPaNa"} = 'sidev/fuellstand/fill_level_*';			#Path+Name des StateIcon mit * anstatt des Level
	 	$attr{$name}{"devStateStyle"} = 'style="font-size:18px; color:green"';
	 	$attr{$name}{"maxInhaltLiter"} = 10;
	 	$attr{$name}{"cmdIcon"} = 'messung_starten:refresh';
	 	$attr{$name}{"webCmd"} = 'messung_starten';
	 	$attr{$name}{"interval"} = $hash->{INTERVAL};
	 	$attr{$name}{"icon"} = 'sidev/fuellstand/wasser_pegel_otc';					#Path+Name GeraeteIcon
		$attr{$name}{"disable"} = 0;
		$attr{$name}{"timeout"} = 1;
		$attr{$name}{"showTrend"} = 1;  											# Zeigt einen Pfeil für Tendez (steigend, fallend)
		$attr{$name}{"event-on-change-reading"} = '.*';
 	 }
   } 
  elsif($init_done) {
	$hash->{INTERVAL}=$attr{$name}{"interval"};
   }

# Geräte IP suchen wenn nicht angegeben
  if($b_get_sensor == 1) {InternalTimer(gettimeofday()+7, "get_sensor_addr", $hash, 0)};
 
  
  return undef;
}

#####################################
# Sendet Befehl zu Lesen an Liquid_Check
sub SI_Liquid_Check_GetHttpResponse($)
{
    my ($hash) = @_;
	my $remote_host = $hash->{HOST};
	$remote_host =~ s/^\s+//g; #Leerzeichen am Ende entfernen 
	my $remote_port = 80;
	my $command = 'infos.json';		
	my $siurl = "http://$remote_host:$remote_port/$command" ;
    my $name = $hash->{NAME};
    my $param = {
                    url        => $siurl,
                    timeout    => 5,
                    hash       => $hash,                                                                                  # Muss gesetzt werden, damit die Callback funktion wieder $hash hat
                    method     => "GET",                                                                                  # Lesen von Inhalten
                    header     => "agent: TeleHeater/2.2.3\r\nUser-Agent: TeleHeater/2.2.3\r\nAccept: application/json",  # Den Header gemäss abzufragender Daten ändern
                    callback   =>  \&SI_Liquid_Check_ParseHttpResponse                                                    # Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
                };

    HttpUtils_NonblockingGet($param);                                                                                     # Starten der HTTP Abfrage. Es gibt keinen Return-Code. 
}

#####################################
# Wird asynccron aufgerufen wenn Daten empfangen wurden

sub SI_Liquid_Check_ParseHttpResponse($)
{
    my ($param, $err, $data) = @_;
    my $hash = $param->{hash};
    my $name = $hash->{NAME};

    if($err ne "")                                                                                                         # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
    {
        Log3 $name, 3, "error while requesting ".$param->{url}." - $err";  # Eintrag fürs Log
		$hash->{status}="ERROR";
        readingsSingleUpdate($hash, "state", "ERROR",1);		
    }

    elsif($data ne "")                                                                                                     # wenn die Abfrage erfolgreich war ($data enthält die Ergebnisdaten des HTTP Aufrufes)
    {
        #Log3 $name, 3, "url ".$param->{url}." returned: $data";                                                            # Eintrag fürs Log

		# An dieser Stelle die Antwort parsen / verarbeiten mit $data
		my $json;
		eval {
			$json = decode_json($data);
			} or do {
			Log3 $hash, 3, "SI_Liquid_Check: $name json-decoding failed. Problem decoding getting statistical data";
			return;
		};
		# Die Werte "level" und "content" merken
		my $tmp_content = ReadingsVal($name, "measure.content", 0);
		my $tmp_level =  ReadingsVal($name, "measure.level", 0);

		readingsBeginUpdate($hash);	
       eval 
	   {
 		foreach my $key (sort keys %{$json->{'payload'}->{'measure'}}) {
			#print $key." - "; 
			#print $json->{'payload'}->{$key}."\n";
			#Log3 $hash, 3, "SI_Liquid_Check: $name key: $key";
			if ($key ne 'raw'){
				readingsBulkUpdate($hash, 'measure.'.$key, $json->{'payload'}->{'measure'}->{$key});
			}
			else {
		 		foreach my $key2 (sort keys %{$json->{'payload'}->{'measure'}->{'raw'}}) {
 				  #Log3 $hash, 3, "SI_Liquid_Check: $name key: $key-$key2";
				  readingsBulkUpdate($hash, 'measure.'.$key.'.'.$key2, $json->{'payload'}->{'measure'}->{'raw'}->{$key2});
				}  
			}
		}

 	  	if (exists($json->{'payload'}->{'expansion'}->{'oneWire'}->{'sensors'})) 
		{
		  	my @sensors_ow = @{$json->{'payload'}->{'expansion'}->{'oneWire'}->{'sensors'}};
			#Log3 $hash, 3, "SI_Liquid_Check: $name parse1: ".@sensors_ow."\n";
			  my $i = 0; 	
			  for ($i = 0; $i < @sensors_ow; $i++) {
 				my $sensorName = trim($json->{'payload'}->{'expansion'}->{'oneWire'}->{'sensors'}->[$i]->{'friendlyName'});
  				my $sensorValue = $json->{'payload'}->{'expansion'}->{'oneWire'}->{'sensors'}->[$i]->{'temperature'};
				if ($sensorName eq '') {$sensorName = $json->{'payload'}->{'expansion'}->{'oneWire'}->{'sensors'}->[$i]->{'romId'}}
  				Log3 $hash, 4, "SI_Liquid_Check: $name sensor-$sensorName: $sensorValue C°";
	    		readingsBulkUpdate($hash, "sensor-$sensorName", $sensorValue." C°");
			  }
			if ($i > 0){
	    		readingsBulkUpdate($hash, ".sensor-aktive", 1);
			}
		}
		if (exists($json->{'payload'}->{'expansion'}->{'board'}->{'relays'})) 
		{
    		readingsBulkUpdate($hash,".relay-aktive",1);
		  	my @relays_br = @{$json->{'payload'}->{'expansion'}->{'board'}->{'relays'}};
			#Log3 $hash, 3, "SI_Liquid_Check: $name parse2: ".@relays_br."\n";
			for (my $i = 0; $i < @relays_br; $i++) {
 				my $sensorName = trim($json->{'payload'}->{'expansion'}->{'board'}->{'relays'}->[$i]->{'friendlyName'});
  				my $sensorValue = $json->{'payload'}->{'expansion'}->{'board'}->{'relays'}->[$i]->{'state'};
				if ($sensorName eq '') {$sensorName = $i+1}
				if ($sensorValue) {$sensorValue = 'on';} else {$sensorValue = 'off';};
  				Log3 $hash, 4, "SI_Liquid_Check: $name relay-$sensorName: $sensorValue";
	    		readingsBulkUpdate($hash, "relay-$sensorName", $sensorValue);
			}	
		}

		foreach my $key (sort keys %{$json->{'payload'}->{'device'}}) {
			if (($key ne "model")&&($key ne "security")){
   	    		readingsBulkUpdate($hash, 'device.'.$key, $json->{'payload'}->{'device'}->{$key});
			}
			$hash->{SENSOR}=ReadingsVal($name, "device.name", 'device_name: seek');	
		}
		foreach my $key (sort keys %{$json->{'payload'}->{'system'}}) {
			if (($key ne "pump")){
   	    		readingsBulkUpdate($hash, 'system.'.$key, $json->{'payload'}->{'system'}->{$key});
			}	
		}
		foreach my $key (sort keys %{$json->{'payload'}->{'wifi'}->{'station'}}) {
   	    	readingsBulkUpdate($hash, 'station.'.$key, $json->{'payload'}->{'wifi'}->{'station'}->{$key});
		}
		foreach my $key (sort keys %{$json->{'payload'}->{'wifi'}->{'accessPoint'}}) {
   	    	readingsBulkUpdate($hash, 'accessPoint.'.$key, $json->{'payload'}->{'wifi'}->{'accessPoint'}->{$key});
		}
		readingsBulkUpdate($hash, "state", $json->{'payload'}->{'measure'}->{'content'});
		readingsEndUpdate($hash, 1);
		$hash->{status}="Connect";
		
		Log3 $hash, 4, "SI_Liquid_Check: $name parse received json ready";

        # Bei neuem verändertem Messwert den alten Wert speichern
		if (ReadingsVal($name, "measure.level", 0) != $tmp_level) {
			readingsBeginUpdate($hash);	
				readingsBulkUpdate($hash, "last.measure.content", $tmp_content);
				readingsBulkUpdate($hash, "last.measure.level", $tmp_level);
			readingsEndUpdate($hash, 1);
		}
		
		set_Round_Measure($hash);

	   1; # Programmablauf ok  "eval"
	   } or do {
		  my $error = $@ || 'Unknown failure';
		  Log3 $hash, 1, "SI_Liquid_Check: $name json parse error: $error";
		};
    }
    
    # Damit ist die Abfrage zuende.
    #Evtl. einen InternalTimer neu schedulen
}

#############################################
# setzt die gerundeten Werte für "measure.level"
# setzt die gerundeten Werte für "measure.content"
# setzt den gerundeten Wert für "percent"
#

sub set_Round_Measure($)
{
	my ($hash) = @_;
  	$hash = $defs{$hash} if(ref($hash) ne 'HASH');
   	return undef if(!$hash);
	my $name = $hash->{NAME};
  	my $content = ReadingsVal($name, "measure.content", "0");
	my $level = ReadingsVal($name, "measure.level", "0");
	my $gesInhalt = $attr{$name}{'maxInhaltLiter'};
	my $percent = 0;
	my $round10percent = 0;
	if (!defined($gesInhalt)) {$gesInhalt=99999};
	if ($gesInhalt > 0) {
		$percent = int($content/$gesInhalt*100+0.5); 	 # %Wert auf ganze Stelle gerundet
		$round10percent = int($percent/10+0.5)*10;	 	 # Rundet den %Wert für die Levelanzeige auf glatte 10er Werte 0,10,20..100
		if ($round10percent >100) {$round10percent=100}; # RoundLevel für Icons auf 100 begrenzen (Falls der Ges.Inhalt zu klein angegeben wurde)
	}
	if ($content > 99) {$content = int($content+0.5)};  # Bei Menge > 99 Liter auf ganze Liter runden
	if (int($level*100+0.3) == int($level*100)) {
		if (int($level*100+0.6) > int($level*100)) {	# level Nachkomma < 0.7
			$level = (int($level*100)+0.5)/100;			# Digit 0.5 anhängen wenn 0.4 - 0.6
		}
		else {$level=int($level*100)/100};						# Abrunden wenn 0.1 - 0.3
	}
	else {$level=int($level*100+1)/100};				# Aufrunden wenn 0.7 - 0.9
	#$level = int($level*100+0.5)/100;  					# Pegelhöhe auf 2 Kommastellen Runden 

	readingsBeginUpdate($hash);	
	#	readingsBulkUpdate($hash, "round.content", $content);
	#	readingsBulkUpdate($hash, "round.level", $level);
		readingsBulkUpdate($hash, "round.percent", $percent);
		readingsBulkUpdate($hash, "round10.percent", $round10percent);
	readingsEndUpdate($hash, 1);

}

###########################################################
# Wird durch FHEM aufgerufen, wenn der Timer abgelaufen ist
# Wird abhängig von <interval> zyklisch aufgrufen 
###########################################################
sub SI_Liquid_Check_Read($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
#   	RemoveInternalTimer($hash);    
	return "Device disabled in config" if ($attr{$name}{"disable"} eq "1");
	InternalTimer(gettimeofday()+$hash->{INTERVAL}, "SI_Liquid_Check_Read", $hash, 0);
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(gettimeofday()+$hash->{INTERVAL});
	my @adays = qw(So Mo Di Mi Do Fr Sa);
	my @amonth = qw(Jan Feb Mär Apr Mai Jun Jul Aug Sep Okt Nov Dez);
	$year += 1900;
	$hash->{NEXTUPDATE}=sprintf("%s %2d. %s %04d - %02d:%02d",$adays[$wday],$mday,$amonth[$mon],$year,$hour,$min);
	Log3 $hash, 4, "SI_Liquid_Check: $name Read called:$hash->{SENSOR}:-:$hash->{status}:";
	readingsBeginUpdate($hash);	
	readingsBulkUpdate($hash, "nextupdate", sprintf("%s %2d. %s %04d - %02d:%02d",$adays[$wday],$mday,$amonth[$mon],$year,$hour,$min));
    readingsBulkUpdate($hash, "nextupdtime",sprintf("%02d:%02d:%02d",$hour,$min,$sec));		
	readingsEndUpdate($hash, 1);
	if (($hash->{SENSOR} =~ m/.*not found.*/) or ($hash->{status} eq 'ERROR')) {
	   	Log3 $hash, 3, "SI_Liquid_Check: $name no Sensor found or Read-Error";
        readingsSingleUpdate($hash, "state", "ERROR",1);		
		#Timer auf kurze Wiederholung (Intervall /3) einstellen
  		RemoveInternalTimer($hash);    
		InternalTimer(gettimeofday()+int($hash->{INTERVAL}/3), "SI_Liquid_Check_Read", $hash, 0);
		#$hash->{NEXTUPDATE}=localtime(gettimeofday()+int($hash->{INTERVAL}/3));
		#get_sensor_addr($hash);
  		$hash->{status}='Try to connect'; 
  		$hash->{SENSOR}='device_name: seek';
		#get_sensor_addr($hash);
		
	}
	else {
   		#Log3 $hash, 3, "SI_Liquid_Check: $name Read called";
		SI_Liquid_Check_GetHttpResponse($hash);
	}
}

#####################################
sub SI_Liquid_Check_Get($$@)
{
	my ($hash, $name, $cmd, @args) = @_;
	#my $name = $hash->{NAME};
	#return "Device disabled in config" if ($attr{$name}{"disable"} eq "1");
	#return "Unknown argument $a[1], choose one of on off " if($a[1] ne "level" & $a[1] ne "lesen");

	if ($cmd eq "sensor_lesen") {
		Log3 $hash, 3, "SI_Liquid_Check: $name Get <". $cmd ."> called";
		SI_Liquid_Check_GetHttpResponse($hash);
		#Log3 $hash, 3, "SI_Liquid_Check: $name Get end";
		if ($attr{$name}{"disable"} ne "1") {   # Intervall nur starten wenn not disable
			InternalTimer(gettimeofday()+$hash->{INTERVAL}, "SI_Liquid_Check_Read", $hash, 0);
		}	
	} 	 
	elsif ($cmd eq "suche_sensor") {
			Log3 $hash, 3, "SI_Liquid_Check: $name Set <". $cmd ."> called";
			get_sensor_addr($hash);
	}
	else{
		return "Unknown argument $cmd, choose one of sensor_lesen:noArg suche_sensor:noArg";
	} 
	# Log3 $hash, 3, "SI_Liquid_Check: $name Get end";	
}



#####################################
sub SI_Liquid_Check_Set($$@)
{
	my ( $hash, $name, $cmd, $args) = @_;
  	#my $name= $hash->{NAME};
	return "Device disabled in config" if ($attr{$name}{"disable"} eq "1");
   	#Log3 $hash, 3, "SI_Liquid_Check: $name Set <". $a[1] ."> called";

	
	if ($cmd eq "messung_starten") {
			Log3 $hash, 3, "SI_Liquid_Check: $name Set <". $cmd ."> called";
			my $remote_host = $hash->{HOST};
			my $p1 = '{\"header\":{\"namespace\":\"Device.Control\",\"name\":\"StartMeasure\",\"messageId\":\"1\",\"payloadVersion\":\"1\"},\"payload\":null}';
			my $param = 'echo "'.$p1.'" | curl --data-binary @- http://'.$remote_host.'/command';
			qx "$param";
			InternalTimer(gettimeofday()+15, "SI_Liquid_Check_Read", $hash, 0);
		    readingsSingleUpdate($hash, "state", "Messen",1);		

	}
	elsif ($cmd eq "readings_sensor-_loeschen") {
			foreach my $readingVal (keys %{$hash->{'READINGS'}}) {
			  Log3 $hash, 3, "SI_Liquid_Check: $name Set $readingVal";
			  if ($readingVal =~ m/sensor-/) {
  				Log3 $hash, 3, "SI_Liquid_Check: $name readingsDelete: $readingVal";
 				readingsDelete($hash, $readingVal);			
			  }
			}  
	}
	elsif ($cmd eq "readings_relay-_loeschen") {
			foreach my $readingVal (keys %{$hash->{'READINGS'}}) {
			  Log3 $hash, 4, "SI_Liquid_Check: $name Set $readingVal";
			  if ($readingVal =~ m/relay-/) {
  				Log3 $hash, 3, "SI_Liquid_Check: $name readingsDelete: $readingVal";
 				readingsDelete($hash, $readingVal);			
			  }
			}  
	}
	elsif (ReadingsVal($name,".relay-aktive",0)== 0 and ReadingsVal($name,".sensor-aktive",0)== 0) {
			return "Unknown argument $cmd, choose one of messung_starten:noArg"
	}
	elsif (ReadingsVal($name,".sensor-aktive",0)== 0) {
			return "Unknown argument $cmd, choose one of messung_starten:noArg readings_relay-_loeschen:noArg"
	}
	elsif (ReadingsVal($name,".relay-aktive",0)== 0) {
			return "Unknown argument $cmd, choose one of messung_starten:noArg readings_sensor-_loeschen:noArg"
	}
	else {
			return "Unknown argument $cmd, choose one of messung_starten:noArg readings_sensor-_loeschen:noArg readings_relay-_loeschen:noArg"
	}
	return undef;
}


#####################################
sub SI_Liquid_Check_Undefine($$)
{
	my ($hash, $arg) = @_;
	my $name= $hash->{NAME};
	RemoveInternalTimer($hash);    
	Log3 $hash, 3, "SI_Liquid_Check: $name undefined.";
	return undef;
}


#####################################
sub SI_Liquid_Check_Delete {
	my ($hash, $arg) = @_;
	my $name= $hash->{NAME};
	Log3 $hash, 3, "SI_Liquid_Check: $name deleted.";
	return undef;
}


#####################################
sub SI_Liquid_Check_Attr {
	my ($cmd,$name,$aName,$aVal) = @_;
	my $hash = $defs{$name};
  
	if ($aName eq "devStateIcPaNa") {
		Log3 $hash, 3, "SI_Liquid_Check: $name devStateIcPaNa set " ;
	}

	if ($aName eq "maxInhaltLiter") {
		if ($cmd eq "set") {
			if (($aVal > 99999) or ($aVal < 1)) {
				Log3 $hash, 3, "$name: $aName set to $aVal fehlgeschlagen";	
 				return 'Nur Werte 1-99999 moeglich!';
				}	
			else {
				set_Round_Measure($hash);
				}		
		}
	}
	if ($aName eq "interval") {
		if ($cmd eq "set") {
			if (($aVal > 86400) or ($aVal < 10)) {
				Log3 $hash, 3, "$name: $aName set to $aVal fehlgeschlagen";	
				return 'Abfrageintervall, Sekunden-Werte 10-86400 moeglich!';
			}
			else {
				$hash->{INTERVAL} = $aVal;
			}
		}	
	}

	return undef;
}

####################################################################
#Ermittelt die IP-Adresse etc. des SI-Sensors mittels UDP Broadcast
####################################################################

sub get_sensor_addr($) 
{
	my ( $hash ) = @_;
	my $name= $hash->{NAME};
	#$hash->{status}='Try to connect';
    readingsSingleUpdate($hash, "state", "Try to connect",1);		

### UDP Broadcast Anfrage für SI-Geräte

	my $MAXLEN  = 512; 						# Empfangspuffe größe
	my $PORTNO  = 2100; 					# Port Nr. des Liqui_Check
	my $timeout = $attr{$name}{"timeout"};  # WarteZeit in Sek nach dem Senden
	
	my $device_ip = "device_ip: ???";
	my $device_uuid = "device_uuid: ???";
	my $device_name = "device_name: not found";

	my $sock = new IO::Socket::INET(
									Proto => 'udp',
									Type => SOCK_DGRAM,
									Timeout => 3,
									Broadcast => 1)
	 	or die Log3 $hash, 3, "SI_Liquid_Check: $name get_sensor_addr Can't bind : $@\n";	
	$sock->sockopt(SO_BROADCAST, 1);
	$sock->sockopt(SO_REUSEADDR, 1);	
	$sock->autoflush(1); 	
	$sock->blocking(0);

	my $data = 'M-SEARCH * HTTP/1.1 HOST: 239.255.255.240:2100 MAN: "ssdp:discover" ST: urn:sielektronik:device:**';
	my $broadcastAddr = sockaddr_in( $PORTNO, INADDR_BROADCAST );
	send( $sock, $data, 0,  $broadcastAddr );
	sleep($timeout);

###	Broadcast Antwort empfangen
	my $datagram;
	my $bytes = sysread($sock,$datagram,$MAXLEN);
	if (not defined $bytes or $bytes < 0) {	# read error
		Log3 $hash, 3, "SI_Liquid_Check: $name get_sensor_addr: Keine Antwort!";
		$device_name = "device_name: not found";
	} 
	elsif ($bytes == 0) {			# eof
		Log3 $hash, 3, "SI_Liquid_Check: $name get_sensor_addr: Leere Antwort!";
		$device_name = "device_name: not found";
	}
	else {
		#print "Received datagram from \n".$datagram;
		($device_ip) = ($datagram =~ /LOCATION.*\/\/([\d]+.[\d]+.[\d]+.[\d]+):.*/);
		($device_name) = ($datagram =~ /:urn:si.*:de.*:(.*):/);
		($device_uuid) = ($datagram =~ /uuid:(.*)::.*/);
		#print $device_name."\n";
		#print $device_ip."\n";
		#print $device_uuid."\n";
	}
	$sock->close();

### Empfangene Parameter im Gerät setzen
  	$hash->{HOST}=$device_ip;
  	$hash->{SENSOR}=$device_name;
	if ($device_name =~ m/.*not found.*/) {
		$hash->{status}="ERROR";
        readingsSingleUpdate($hash, "state", "ERROR",1);		
	}
	else {
		$hash->{status}="Connect";
        readingsSingleUpdate($hash, "state", "Wait",1);				
  		RemoveInternalTimer($hash,"get_sensor_addr");    
	}
	#fhem("define at1 at +00:00:02 setreading $name uuid $device_uuid");
	Log3 $hash, 3, "SI_Liquid_Check: $name get_sensor_addr $hash->{SENSOR}, $hash->{HOST}";
}


#####################################
sub SI_Liquid_Check_devStateIcon($)
{
	my ($hash) = @_;
  	$hash = $defs{$hash} if(ref($hash) ne 'HASH');
   	return undef if(!$hash);
  	return undef if($hash->{helper}->{group});
	my $name = $hash->{NAME};
	my $pathName = $attr{$name}{"devStateIcPaNa"};  # Icon Pfad und Name ohne %-Endung z.B für fill_level_10.svg /images/default/sidev/fuellstand/fill_level_*.svg
	my ($pathName1) = ($pathName =~ m/(.*)\*/); # Erster Teil ohne % Angabe
	my ($pathName2) = ($pathName =~ m/\*(.*)/); # Endung nach der % Angabe
	my $anzStelle = 1; # Anzahl der Kommastelle bei sprintf für den Wert "content"
  	my $content = ReadingsVal($name, "measure.content", 0);
	my $level = ReadingsVal($name, "measure.level", 0);
	my $lastlevel = ReadingsVal($name, "last.measure.level", 0);
	my $percent = ReadingsVal($name, "round.percent", 0);
	my $roundlevel = ReadingsVal($name, "round10.percent", 0);
	my $state = ReadingsVal($name, "state", 0);
	#Log3 $hash, 3, "SI_Liquid_Check: $name $hash->{NAME},\n".$pathName1.$roundlevel.$pathName2."\n end\n";
	my $myIcon='';
	my $myIcon2='';
	if ($content > 99) {$anzStelle = 0; };  # Bei sprintf, Menge > 99 Liter ohne Komma anzeigen
	
	if ($state eq "Messen") {$myIcon = FW_makeImage('time_timer@orange')}	
	elsif ($roundlevel > 10){$myIcon = FW_makeImage($pathName1.$roundlevel.$pathName2.'@green')}
	else {$myIcon = FW_makeImage($pathName1.$roundlevel.$pathName2.'@red')};	
	
	if ($attr{$name}{'showTrend'} eq 1) { 
		if ($lastlevel lt $level) {$myIcon2 = FW_makeImage('control_arrow_up_right')}
		elsif ($lastlevel gt $level) {$myIcon2 = FW_makeImage('control_arrow_down_right')}
		else {$myIcon2 = FW_makeImage('control_arrow_right')};
	}

	return '<div>
				<div style="margin-left: 100px; float:left; margin-top: 10px"> 
					'.$myIcon.'					
				</div> 
				<div style="margin-left: 80px; width: 200px; margin-top: 10px; text-align: center;">
					'.sprintf("Höhe: %.2f&nbspm", $level).'<br>'
					.sprintf("Menge: %.${anzStelle}f&nbspL", $content).'<br>'
					.sprintf("&nbsp(%.0f&nbsp%%) ", $percent).$myIcon2.'
				</div>
			</div>';
			#  &nbsp ist ein geschütztes Leerzeichen (Kein Zeilenumbruch)
			# %% ist ein %-Zeichen
}  


#####################################

# [http://www.somacon.com/p114.php http://www.somacon.com/p114.php]
# Perl trim function to remove whitespace from the start and end of the string
sub trim($)
{ 
  my $string = shift;
  $string =~ s/\s+//g;   # Löscht alle Leerzeichen
  #$string =~ s/^\s+//;   # Löscht von links
  #$string =~ s/\s+$//;   # Löscht von rechts
  return $string;
} 
# Left trim function to remove leading whitespace
sub ltrim($)
{
  my $string = shift;
  $string =~ s/^\s+//;
  return $string;
}
# Right trim function to remove trailing whitespace
sub rtrim($)
{
  my $string = shift;
  $string =~ s/\s+$//;
  return $string;
}

###############################################################

1;



=pod

=begin html

<a id="SI_Liquid_Check"></a>
<h3>SI_Liquid_Check 1.5</h3>
<ul>
  <br>

  <a name="SI_Liquid_Check"></a>
  <b>Description</b><br>
  	This is an FHEM-Module for integration the SI-Elektronik GmbH Level-Sensor 'SI_Liquid_Check',with and without switching module SM1,.<br>
	SI_Liquid_Check is a wifi controlled Level-Sensor for Water tanks or other liquids.<br>
  	The measuring method is based on a hydrostatic measurement of the filling level.<br>
	It support reading of Fluid_Level and Fluid_Volume.<br>
	The device does not have to be mounted in the tank, it can be mounted directly in a supply room and only needs a thin hose connection to the tank.<br>
	A Liquid-Check with the extension SM1 has 3 switching relays as well as the possibility to connect four 1-wire temperature sensors. 
	The query of the temperature sensors and the relay status are extended in this module.<br>
  <br>
  <b>Define</b>
  	<ul>
    <code>define &lt;name&gt; SI_Liquid_Check [&lt;ip/hostname&gt];</code><br>
    <br>
	Defines a SI_Liquid_Check wifi-controlled level sensor.<br>
	This module automatically detects the modul defined and adapts the readings accordingly.<br>
	</ul>
	<br>
	The Parameter "ip/hostname" is optional because the module find the running Liqui_Check over an<br>
	udp broadcast call. 
	<p>
  <b>Set</b>
	<ul>
		<li><b>messung_starten</b>:  </li>
			Causes the liquid check to take a measurement. Then the values are read and the interval restarts.
		<li><b>readings_relay_loeschen</b>:  </li>
			Clear old relay-name.
		<li><b>readings_sensor_löschen</b>:  </li>
			Clear old namen of the temperatur-sensors.
	</ul>		
  <p>
  <b>Get</b>
	<ul>
		<li><b>sensor_lesen</b>:  </li>
			Reads the last readings from the Liquid-Check, no active measurement is performed on the device.
		<p>	
		<li><b>suche_sensor</b>:  </li>
			Search the Liquid-Check on the network and save the determined IP. <br>	
	</ul>		
  <p>	<br>
  <b>Readings</b>
	<ul>
		Essential Readings, most are self-explanatory
		<p>
		<li><b>...</b>  </li>
		<p>
		<li><b>last.measure.content</b>:  </li>
		Capacity in liters before the last change
		<p>
		<li><b>last.measure.level</b>:  </li>
		Level in meters before the last change
		<p>
		<li><b>measure.content</b>:  </li>
		Capacity in liters, last updated
		<p>
		<li><b>measure.level</b>:  </li>
		Level in meters, last current level rounded to 1cm or 0.01m
		<p>
		<li><b>measure.raw.content</b>:  </li>
		Filling quantity in liters with maximum resolution, last current status
		<p>
		<li><b>measure.raw.level</b>:  </li>
		Level in meters with maximum resolution, last current level.  
		<p>
		<li><b>nextupdate</b>:  </li>
		Date and time for the next reading of the sensor (determined by the interval)
		<p>
		<li><b>nextupdtime</b>:  </li>
		Time for the next reading of the sensor (determined by the interval)
		<p>
		<li><b>round.percent</b>:  </li>
		Percentage level indicator. Depending on the attribute "maxInhaltLiter"
		<p>
		<li><b>round10.percent</b>:  </li>
		Percentage in increments of 10 rounded for use in icon with different fill levels
		<p>
		<li><b>...</b>  </li>
		If the unit is equipped with the switching module "SM1", then further readings for temperature and relay status are displayed
	</ul>	
  <p>	<br>
   <b>Attributs</b>
	<ul>
		<li><b>interval</b>: The interval in seconds, after which FHEM will update the current measurements. Default: 300 Sec.(5 Min.)</li>
			An update of the measurements is also done on each "get sensor_lesen" as well.
		<p>
		<li><b>timeout</b>:  Timeout in seconds used while finding the ip/Adress of the Sensor. Default: 1s</li>
			<i>Warning:</i>: the timeout of 1s is chosen fairly aggressive. It could lead to errors, if the Sensor is not answerings the requests
			within this timeout. Please consider, that raising the timeout could mean blocking the whole FHEM during the timeout!
		<p>
		<li><b>disable</b>: The execution of the module is suspended. Default: no.</li>
			<i>Warning:</i> if your Liquid-Check is not on or not connected to the wifi network, consider disabling this module
			by the attribute "disable". Otherwise the cyclic update of the Sensor seek funktion will lead to blockings in FHEM.
		<p>
		<li><b>devStateIcPaNa</b>: devStateIcPaNa=sidev/fuellstand/fill_level_* </li>
		The path and name of an "Extend devStateIcon" instead of the percentage (0, 10, 20, .. 100) is given a "*". The path
		is specified starting from the standard icon path "/ opt / fhem / www / images / default /" (Fhem Raspi installation).
		<p>
		<li><b>devStateIcon</b>: devStateIcon={SI_Liquid_Check_devStateIcon($name)}</li>
		Predefined function for representing values and state icon together.
		<p>
		<li><b>icon</b>: 2 dev icons will be found at</li><br>
		1. "sidev/fuellstand/wasser_pegel_otc"; 2. "sidev/fuellstand/oel_pegel_otc"	
		<p>
		<li><b>maxInhaltLiter</b>: Maximum capacity of the tank in liters.</li>
		 Is needed so that a percentage level calculation can be made.
		<p>
		<li><b>showTrend</b>: Show or hide the trend arrow </li>
		Indicates with an arrow whether the current measured value increases or decreases in relation to the preceding change.	
		
	</ul>
  <p>
  <b>Requirements</b>
	<ul>
	This module uses the follwing perl-modules:<br><br>
	<li> Perl Module: IO::Socket::INET </li>
	</ul>

</ul>

=end html


=begin html_DE

<a id="SI_Liquid_Check"></a>
<h3>SI_Liquid_Check 1.5</h3>
<ul>
  <br>

  <a name="SI_Liquid_Check"></a>
    <b>Beschreibung</b><br>
	Dises Modul integriert den SI-Elektronik GmbH Level-Sensor 'SI_Liquid_Check', mit und ohne Schaltmodul SM1, in FHEM. <br>
	'SI-Liqui_Check' ist ein Level-Sensor mit WLAN zur Füllstandsmessung in Wassertanks oder für anderen drucklosen Flüssigkeiten.<br>
	Die Meßmethode basiert auf einer hydrostatischen Messung des Flüssigkeitspegel in einem Behälter.<br>
	Das Gerät muss nicht im Tank montiert werden, es kann direkt in einem Versorgungsraum angebracht werden und benötigt nur eine dünne Schlauchverbindung zum Tank.<br>
	Ein Liquid-Check mit der Erwiterung SM1 verfügt über 3 Schaltrelais sowie der Möglichkeit vier Stk. 1-Wire Temp.Sensoren anzuschließen. 
	Die Abfrage der Temperatursensoren sowie des Relaisstatus sind in diesem Modul erweitert.<br>
	<br>
  <a href="https://si-elektronik.de/IoT/Liquid-Check/Documents/liquid_check_doku.pdf" target="_blank">Komplette Dokumentation als Pdf</a> <br>
  	<br>
  <b>Define</b> 
  	<ul>
    <code>define &lt;name&gt; SI_Liquid_Check [&lt;ip/hostname&gt];</code><br>
   	<br>
    Definiert einen SI_Liquid_Check level sensor. <br>
	Die Angabe von "ip/hostname" ist optional, das Modul sendet einen UDP-Broadcast, dabei erkennt es automatisch eine SI_Liquid_Check Gerät im Netzwerk und setzt die "ip/host-Adresse" entsprechend. 
	</ul>
	<br>
  <p>
  <b>Set</b>
	<ul>
		<li><b>messung_starten</b>:  </li>
			Veranlasst den Liquid-Check eine Messung durchzuführen. Danach werden die Werte gelesen und der Intervall startet neu.
		<li><b>readings_relay_loeschen</b>:  </li>
			Veraltete Relais-Namen löschen.
		<li><b>readings_sensor_löschen</b>:  </li>
			Veraltete Namen der Temperatur-Sensoren löschen.
	</ul>		
	<br><p>
  <b>Get</b>
	<ul>
		Diese beiden Funktionen werden automatisch 5sek. nach dem Erstellen des Gerätes ausgeführt.
		<p>
		<li><b>sensor_lesen</b>:  </li>
			Liest die letzten Messwerte vom Liquid-Check, es wird keine aktive Messung am Gerät ausgeführt.
		<p>			
		<li><b>suche_sensor</b>:  </li>
			Sucht den Liquid-Check im Netzwerk und speichert die ermittelte IP.<br>

	</ul>		
  <p>	<br>
  <b>Readings</b>
	<ul>
		Wesentliche Readings, die meisten sind selbsterklärend
		<p>
		<li><b>...</b>  </li>
		<p>
		<li><b>last.measure.content</b>:  </li>
		Füllmenge in Liter vor der letzten Änderung
		<p>
		<li><b>last.measure.level</b>:  </li>
		Füllstand in Meter vor der letzten Änderung
		<p>
		<li><b>measure.content</b>:  </li>
		Füllmenge in Liter, letzter aktueller Stand
		Berechnet mit 'measure.level' unter Berücksichtigung der Formparameter des Tanks
		<p>
		<li><b>measure.level</b>:  </li>
		Füllstand in Meter, letzter aktueller Stand gerundet auf 1cm bzw. 0,01m
		<p>
		<li><b>measure.raw.content</b>:  </li>
		Füllmenge in Liter mit maximaler Auflösung, letzter aktueller Stand
		<p>
		<li><b>measure.raw.level</b>:  </li>
		Füllstand in Meter mit maximaler Auflösung, letzter aktueller Stand.  
		<p>
		<li><b>nextupdate</b>:  </li>
		Datum und Uhrzeit für das nächste Lesen des Sensors (Festgelegt durch den Intervall)
		<p>
		<li><b>nextupdtime</b>:  </li>
		Uhrzeit für das nächste Lesen des Sensors (Festgelegt durch den Intervall)
		<p>
		<li><b>round.percent</b>:  </li>
		Prozentwert für die Füllstandsanzeige. Abhängig vom Attribut "maxInhaltLiter"
		<p>
		<li><b>round10.percent</b>:  </li>
		Prozentwert in 10er Schritten gerundet zur Verwendung im Icon mit verschiedenen Füllgraden
		<p>
		<li><b>...</b>  </li>
		Ist das Gerät mit dem Schaltmodul "SM1" ausgestattet, dann werden weitere Readings für
		Temperatur und Relaiszustand angezeigt
	</ul>	
  <p>	<br>	
  <b>Attribute</b>
	<ul>
		<li><b>interval</b>: Das Intervall in Sekunden, nach dem FHEM die Messwerte aktualisiert. Default: 300 Sek.(5 Min.)</li>
			Eine Aktualisierung der Messwerte findet auch bei jedem "get sensor_lesen" über die "non-blocking" Methode statt.
		<p>
		<li><b>timeout</b>:  Der Timeout in Sekunden, der bei Suchen des Sensors verwendet wird. Default: 1s</li>
			<i>Achtung</i>: der Timeout von 1s ist knapp gewählt. Ggf. kann es zu Fehlermeldungen kommen, wenn der Sensor nicht 
			schnell genug antwortet. Bitte beachten Sie aber auch, dass längere Timeouts FHEM für den Zeitraum des Requests blockieren!<br>
			Das zyklische Lesen der Messwerte mittels 'interval' erfolgt nicht mit einem &lt;timeout&gt; sondern über die "non-blocking" Methode.
		<p>
		<li><b>disable</b>: Die Ausführung des Moduls wird gestoppt. Default: no.</li>
			<i>Achtung:</i> wenn Liquid-Check nicht in Betrieb oder über das WLAN erreichbar ist, sollten Sie
			dieses FHEM-Modul per Attribut "disable" abschalten, da sonst beim zyklischen Suchen der ip/Adresse
			des Sensors Timeouts auftreten, die FHEM unnötig verlangsamen.
		<p>
		<li><b>devStateIcPaNa</b>: devStateIcPaNa=sidev/fuellstand/fill_level_* </li>
		Pfad und Name eines "Extend devStateIcon" anstatt des Prozentwertes (0 ,10, 20..100) wird ein "*" angegeben. Der Pfad 
		ist ausgehend vom Standard Icon Pfad "/opt/fhem/www/images/default/"(Fhem Raspi-Installation) angegeben.
		<p>
		<li><b>devStateIcon</b>: devStateIcon={SI_Liquid_Check_devStateIcon($name)} </li>
		Vordefinierte Funktion, damit Messwerte und State Icon zusammen dargestellt werden.
		<p>
		<li><b>icon</b>: Es werden 2 Geräte Icon zur Verfügung gestellt </li><br>
		1. "sidev/fuellstand/wasser_pegel_otc"; 2. "sidev/fuellstand/oel_pegel_otc"
		<p>
		<li><b>maxInhaltLiter</b>: Maximale Füllmenge des Tanks in Liter. </li>
		Wird benötigt, damit eine prozentuale Füllstandsberechnung gemacht werden kann.	
		<p>
		<li><b>showTrend</b>: Ein oder Ausblenden des Trend-Pfeils </li>
		Zeigt mit einem Pfeil an, ob der aktuelle Messwert gegenüber der davor liegenden Änderung steigt oder sinkt.	
	</ul>
  <p>	<br>
  <b>Requirements</b>
	<ul>
	Das Modul benötigt die folgenden Perl-Module:<br><br>
	<li> Perl Module: IO::Socket::INET </li>
	</ul>

</ul>

=end html_DE

=item summary Connection of the Liquid_Check WIFI level sensor (hydrostatic)
=item summary_DE  Anbindung des Liquid_Check WLAN Levelsensor (hydrostatisch)
=item device

=cut
