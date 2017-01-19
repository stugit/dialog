#!/bin/bash

dialog	--title " Welcome to My Menu! " \
		--column-separator "|"			\
		--menu "" 19 40 12              \
			"1" "Option One | DEV1" 	\
			"2" "Option Two | DEV2"		\
			"3" "Option Three | UAT"	\
			"4" "Option Four | PRD"     \
			"5" "Option Five | BCP"     \
2>temp
Cancelled=$?
Choice=`cat  temp` ; rm temp
if [ $Cancelled -eq  0 ];
	then echo "You selected: $Choice"
	else echo "You cancelled!"
fi
