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



SI_Liquid_Check

 Beschreibung
 Dises Modul integriert den SI-Elektronik GmbH Level-Sensor 'SI_Liquid_Check' in FHEM. 
 'SI-Liqui_Check' ist ein Level-Sensor mit WLAN zur Füllstandsmessung in Wassertanks oder für andere drucklose Flüssigkeiten.
 Die Meßmethode basiert auf einer hydrostatischen Messung des Flüssigkeitspegel in einem Behälter.
 Das Gerät muss nicht im Tank montiert werden, es kann direkt in einem Versorgungsraum angebracht werden und benötigt nur eine dünne Schlauchverbindung zum Tank.

Komplette Dokumentation als Pdf 

Define define <name> SI_Liquid_Check (<ip/hostname>);

 Definiert einen SI_Liquid_Check level sensor. 
 Die Angabe von "ip/hostname" ist optional, das Modul sendet einen UDP-Broadcast, dabei erkennt es automatisch eine SI_Liquid_Check Gerät im Netzwerk und setzt die "ip/host-Adresse" entsprechend. 


Attribute 
◦interval: Das Intervall in Sekunden, nach dem FHEM die Messwerte aktualisiert. Default: 3600 Sek.(1 Std.)
Eine Aktualisierung der Messwerte findet auch bei jedem "get sensor_lesen" über die "non-blocking" Methode statt. 

◦timeout: Der Timeout in Sekunden, der bei Suchen des Sensors verwendet wird. Default: 1s
Achtung: der Timeout von 1s ist knapp gewählt. Ggf. kann es zu Fehlermeldungen kommen, wenn der Sensor nicht schnell genug antwortet. Bitte beachten Sie aber auch, dass längere Timeouts FHEM für den Zeitraum des Requests blockieren!
 Das zyklische Lesen der Messwerte erfolgt nicht mit einem <timeout> sondern über die "non-blocking" Methode. 

◦disable: Die Ausführung des Moduls wird gestoppt. Default: no.
Achtung: wenn Ihr Liquid-Check nicht in Betrieb oder über das WLAN erreichbar ist, sollten Sie dieses FHEM-Modul per Attribut "disable" abschalten, da sonst beim zyklischen Suchen der ip/Adresse des Sensors Timeouts auftreten, die FHEM unnötig verlangsamen. 

◦devStateIcPaNa=sidev/fuellstand/fill_level_*:
 Pfad und Name eines "Extend devStateIcon" anstatt des Prozentwertes (0 ,10, 20..100) wird ein "*" angegeben. Der Pfad ist ausgehend vom Standard Icon Pfad "/opt/fhem/www/images/default/"(Fhem Raspi-Installation) angegeben. 


◦devStateIcon={SI_Liquid_Check_devStateIcon($name)}:
 Vordefinierte Funktion, damit Messwerte und State Icon zusammen dargestellt werden. 

Requirements 
Das Modul benötigt die folgenden Perl-Module:

◦ Perl Module: IO::Socket::INET 
