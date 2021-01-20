# FHEM Module Liquid-Check 
**Fhem Modul and Documentation for the "Liquid-Check" Levelsensor.**

- liquid_check_doku.pdf
  - [Documentation](https://github.com/Roma61/Liquid-Check/blob/master/liquid_check_doku.pdf) of the "Liquid-Check" Levelsensor device
  
- src/FHEM/24_SI_Liquid_Check.pm
  - Fhem Modul for easy integration of the Levelsensor, copy this module to fhem: ./FHEM/
  
- src/www/images/default/sidev/fuellstand/\*.\*
  - this icons are the default icons for the fhem-modul "24_SI_Liquid_Check.pm", unpack icons to ./www/images/default/     
  
*For easy download use FHEM-Update feature /see "Installation"*  


## Übersicht Geräte

### Liquid-Check Aufbau
<img src="Uebersichtrouter.jpg" />

## Übersicht Fhem
*Eine Besonderheit ist, dass StateIcon und Werte angezeigt werden.
Des Weitern können beliebige Icons als StateIcon verwendet werde dessen Dateiname mit 10, 20 ... 100 endet.*

![Fhem-Ansicht](https://raw.githubusercontent.com/roma61/Liquid-Check/master/FHEM-Fuellstand.jpg)

![Fhem-Ansicht](https://raw.githubusercontent.com/roma61/Liquid-Check/master/Fhem-LCSM1-Device.jpg)

![Fhem-Ansicht](https://raw.githubusercontent.com/roma61/Liquid-Check/master/Fhem-LCSM1-SVG.jpg)

## Install
*Run the following commands in FHEM command-line to add this repository to your FHEM setup:*
```
update add https://raw.githubusercontent.com/roma61/Liquid-Check/master/src/controls_liquid_check.txt
update all liquid_check
shutdown restart

```

