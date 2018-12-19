# Liquid-Check
Documentation and Fhem Modul for the "Liquid-Check" levelsensor
<p>
liquid_check_doku.pdf       <tab>- Documentation of the "Liquid-Check" Levelsensor device
<p>  
24_SI_Liquid_Check.pm       - Fhem Modul for easy integration of the Levelsensor<br>
  copy this module to fhem /opt/fhem/FHEM/  (Fhem Raspi-Installation)
<p>  
icons.rar                   - this icons are the default icons for the fhem-modul 24_SI_Liquid_Check.pm<br>
  unpack this icons to /opt/fhem/www/images/default/sidev/fuellstand/                              
<p>
<br>
<h3>Helpfile SI_Liquid_Check.pm EN</h3>

<a name="SI_Liquid_Check" english></a>
<h3>SI_Liquid_Check</h3>
<ul>
  <br>

  <a name="SI_Liquid_Check"></a>
  <b>Description</b><br>
  	This is an FHEM-Module for integration the SI-Elektronik GmbH Level-Sensor 'SI_Liquid_Check'.<br>
	SI_Liquid_Check is a wifi controlled Level-Sensor for Water tanks or other liquids.<br>
  	The measuring method is based on a hydrostatic measurement of the filling level.<br>
	It support reading of Fluid_Level and Fluid_Volume.<br>
	The device does not have to be mounted in the tank, it can be mounted directly in a supply room and only needs a thin hose connection to the tank.<br>
  <br>
  <b>Define</b>
    <code>define &lt;name&gt; SI_Liquid_Check (&lt;ip/hostname&gt);</code><br>
    	<br>
	Defines a SI_Liquid_Check wifi-controlled level sensor.<br>
	This module automatically detects the modul defined and adapts the readings accordingly.<br>
	<br><br>
	The Parameter "ip/hostname" is optional because the module find the running Liqui_Check over an<br>
	udp broadcast call. 
	<p>
  <b>Attributs</b>
	
		<li><b>interval</b>: The interval in seconds, after which FHEM will update the current measurements. Default: 3600 Sec.<br>
			An update of the measurements is also done on each "get sensor_lesen" as well.</li>
		<p>
		<li><b>timeout</b>:  Timeout in seconds used while finding the ip/Adress of the Sensor. Default: 1s</li>
			<i>Warning:</i>: the timeout of 1s is chosen fairly aggressive. It could lead to errors, if the Sensor is not answerings the requests
			within this timeout. Please consider, that raising the timeout could mean blocking the whole FHEM during the timeout!
		<p>
		<li><b>disable</b>: The execution of the module is suspended. Default: no.</li>
			<i>Warning: if your Liquid-Check is not on or not connected to the wifi network, consider disabling this module
			by the attribute "disable". Otherwise the cyclic update of the Sensor seek funktion will lead to blockings in FHEM.</i>
		<p>
		<li><b>devStateIcPaNa=sidev/fuellstand/fill_level_\*</b>:<br>
		The path and name of an "Extend devStateIcon" instead of the percentage (0, 10, 20, .. 100) is given a "*". The path
		is specified starting from the standard icon path "/ opt / fhem / www / images / default /" (Fhem Raspi installation).
		<p>
		<li><b>devStateIcon={SI_Liquid_Check_devStateIcon($name)}</b>:
		Predefined function for representing values and state icon together.
		

  <p>
  <b>Requirements</b>
	<ul>
	This module uses the follwing perl-modules:<br><br>
	<li> Perl Module: IO::Socket::INET </li>
	</ul>

</ul>


<br>
<h3>Hilfetext SI_Liquid_Check.pm DE</h3>



<a name="SI_Liquid_Check"></a>
<h3>SI_Liquid_Check</h3>
<ul>
  <br>

  <a name="SI_Liquid_Check"></a>
    <b>Beschreibung</b><br>
	Dises Modul integriert den SI-Elektronik GmbH Level-Sensor 'SI_Liquid_Check' in FHEM. <br>
	'SI-Liqui_Check' ist ein Level-Sensor mit WLAN zur Füllstandsmessung in Wassertanks oder für andere drucklose Flüssigkeiten.<br>
	Die Meßmethode basiert auf einer hydrostatischen Messung des Flüssigkeitspegel in einem Behälter.<br>
	Das Gerät muss nicht im Tank montiert werden, es kann direkt in einem Versorgungsraum angebracht werden und benötigt nur eine dünne Schlauchverbindung zum Tank.<br>
	<br>
  <a href="https://si-elektronik.de/IoT/Liquid-Check/Documents/liquid_check_doku.pdf" target="_blank">Komplette Dokumentation als Pdf</a> <br>
  	<br>
  <b>Define</b> 
    <code>define &lt;name&gt; SI_Liquid_Check (&lt;ip/hostname&gt);</code><br>
    	<br>
    	Definiert einen SI_Liquid_Check level sensor. <br>
	Die Angabe von "ip/hostname" ist optional, das Modul sendet einen UDP-Broadcast, dabei erkennt es automatisch eine SI_Liquid_Check Gerät im Netzwerk und setzt die "ip/host-Adresse" entsprechend. 
	<br><br>
  <p>
  <b>Attribute</b>
	
		<li><b>interval</b>: Das Intervall in Sekunden, nach dem FHEM die Messwerte aktualisiert. Default: 3600 Sek.(1 Std.)</li>
			Eine Aktualisierung der Messwerte findet auch bei jedem "get sensor_lesen" über die "non-blocking" Methode statt.
		<p>
		<li><b>timeout</b>:  Der Timeout in Sekunden, der bei Suchen des Sensors verwendet wird. Default: 1s</li>
			<i>Achtung</i>: der Timeout von 1s ist knapp gewählt. Ggf. kann es zu Fehlermeldungen kommen, wenn der Sensor nicht 
			schnell genug antwortet. Bitte beachten Sie aber auch, dass längere Timeouts FHEM für den Zeitraum des Requests blockieren!<br>
			Das zyklische Lesen der Messwerte erfolgt nicht mit einem &lt;timeout&gt; sondern über die "non-blocking" Methode.
		<p>
		<li><b>disable</b>: Die Ausführung des Moduls wird gestoppt. Default: no.</li>
			<i>Achtung: wenn Ihr Liquid-Check nicht in Betrieb oder über das WLAN erreichbar ist, sollten Sie
			dieses FHEM-Modul per Attribut "disable" abschalten, da sonst beim zyklischen Suchen der ip/Adresse
			des Sensors Timeouts auftreten, die FHEM unnötig verlangsamen.</i>
		<p>
		<li><b>devStateIcPaNa=sidev/fuellstand/fill_level_**</b>:<br> 
		Pfad und Name eines "Extend devStateIcon" anstatt des Prozentwertes (0 ,10, 20..100) wird ein "*" angegeben. Der Pfad 
		ist ausgehend vom Standard Icon Pfad "/opt/fhem/www/images/default/"(Fhem Raspi-Installation) angegeben.
		<p>
		<li><b>devStateIcon={SI_Liquid_Check_devStateIcon($name)}</b>:<br>
		Vordefinierte Funktion, damit Messwerte und State Icon zusammen dargestellt werden.

  <p>
  <b>Requirements</b>
	<ul>
	Das Modul benötigt die folgenden Perl-Module:<br><br>
	<li> Perl Module: IO::Socket::INET </li>
	</ul>

</ul>
</P>

