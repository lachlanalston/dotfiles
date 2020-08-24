  GNU nano 5.0                                                                     statusbar.sh
#! /bin/bash

dte(){
        dte=""$(date '+%a %b %d %Y')" "$(date '+%I:%M%p')""
        echo "$dte"
}

bat(){

    # Change BAT1 to whatever your battery is identified as. Typically BAT0 or BAT1
    CHARGE=$(cat /sys/class/power_supply/BAT0/capacity)
    STATUS=$(cat /sys/class/power_supply/BAT0/status)

    printf "%s" "$SEP1"
    if [ "$IDENTIFIER" = "unicode" ]; then
        if [ "$STATUS" = "Charging" ]; then
            printf "   ^=^t^l %s%% %s" "$CHARGE" "$STATUS"
        else
            printf "   ^=^t^k %s%% %s" "$CHARGE" "$STATUS"
       fi
    else
        printf "BAT %s%% %s" "$CHARGE" "$STATUS"
    fi
    printf "%s\n" "$SEP2"
}

 alsa () {
    VOL=$(amixer get Master | tail -n1 | sed -r "s/.*\[(.*)%\].*/\1/")
    printf "%s" "$SEP1"
    if [ "$IDENTIFIER" = "unicode" ]; then
        if [ "$VOL" -eq 0 ]; then
            printf "   ^=^t^g"
        elif [ "$VOL" -gt 0 ] && [ "$VOL" -le 33 ]; then
            printf "   ^=^t^h %s%%" "$VOL"
        elif [ "$VOL" -gt 33 ] && [ "$VOL" -le 66 ]; then
            printf "   ^=^t^i %s%%" "$VOL"
        else
            printf "   ^=^t^j %s%%" "$VOL"
        fi
    else
        if [ "$VOL" -eq 0 ]; then
            printf "MUTE"
        elif [ "$VOL" -gt 0 ] && [ "$VOL" -le 33 ]; then
            printf "VOL %s%%" "$VOL"
        elif [ "$VOL" -gt 33 ] && [ "$VOL" -le 66 ]; then
            printf "VOL %s%%" "$VOL"
        else
            printf "VOL %s%%" "$VOL"
        fi
    fi
    printf "%s\n" "$SEP2"
}

wea(){
        LOCATION=""
        curl -s https://wttr.in/$LOCATION?format=1
}

while true; do
        xsetroot -name "$(dte) | $(bat) | $(alsa) | $(wea)"
        sleep 1s
done
