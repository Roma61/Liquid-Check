# FHEM Module Liquid-Check 
**Fhem Modul and Documentation for the "Liquid-Check" Levelsensor.**

- liquid_check_doku.pdf
  - [Documentation](https://raw.githubusercontent.com/roma61/Liquid-Check/master/liquid_check_doku.pdf) of the "Liquid-Check" Levelsensor device
  
- 24_SI_Liquid_Check.pm
  - Fhem Modul for easy integration of the Levelsensor, copy this module to fhem: /opt/fhem/FHEM/  (Fhem Raspi-Installation)
  
- icons.tar.gz
  - this icons are the default icons for the fhem-modul "24_SI_Liquid_Check.pm", unpack icons to /opt/fhem/www/images/default/                        


## Übersicht Geräte

![Liquid-Check Aufbau](https://raw.githubusercontent.com/roma61/Liquid-Check/master/Uebersichtrouter.jpg)


## Übersicht Fhem
*Eine Besonderheit ist, dass StateIcon und Werte angezeigt werden.
Des Weitern können beliebige Icons als StateIcon verwendet werde dessen Dateiname mit 10, 20 ... 100 endet.*

![Fhem-Ansicht](https://raw.githubusercontent.com/roma61/Liquid-Check/master/FHEM-Fuellstand.jpg)

## Install
*Dieses Beispiel geht von einer FEHM-Installation auf einem Raspberry Pi aus*
```
$ wget -P /opt/fhem/FHEM -N https://raw.github.com/roma61/Liquid-Check/master/24_SI_Liquid_Check.pm
$ wget -P /opt/fhem -N https://raw.github.com/roma61/Liquid-Check/master/icons.tar.gz
$ tar xfvz /opt/fhem/icons.tar.gz -C /opt/fhem/www/images/default
$ rm /opt/fhem/icons.tar.gz

```

