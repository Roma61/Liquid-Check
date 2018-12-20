# Liquid-Check FHEM Module
**Documentation and Fhem Modul for the "Liquid-Check" Levelsensor.**

- liquid_check_doku.pdf
  - Documentation of the "Liquid-Check" Levelsensor device
  
- 24_SI_Liquid_Check.pm
  - Fhem Modul for easy integration of the Levelsensor copy this module to fhem /opt/fhem/FHEM/  (Fhem Raspi-Installation)
  
- icons.rar
  - this icons are the default icons for the fhem-modul 24_SI_Liquid_Check.pm unpack icons.rar to /opt/fhem/www/images/default/                        


## Übersicht Geräte

![Liquid-Check Aufbau](https://raw.githubusercontent.com/roma61/Liquid-Check/master/Uebersichtrouter.jpg)


## Übersicht Fhem

![Fhem-Ansicht](https://raw.githubusercontent.com/roma61/Liquid-Check/master/FHEM-Fuellstand.jpg)

## Install

```
$ cd /opt/fhem/www/images/default
$ update add https://raw.githubusercontent.com/klein0r/fhem-tasmota/master/controls_tasmota.txt
$ update add https://raw.githubusercontent.com/roma61/Liquid-Check/readme_edit/controls_liquid_check.txt
```

