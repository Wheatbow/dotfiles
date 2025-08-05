#!/bin/sh

i3status | while :
do
  read line
  battery="$(termux-battery-status)"
  percentage="$(echo "$battery" | jq .percentage)"
  temperature="$(echo "$battery" | jq .temperature)"
  echo "$line | $percentage% $temperature°C"
done
