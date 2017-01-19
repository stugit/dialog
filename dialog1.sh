#!/bin/bash

dialog	--title " Welcome to My Menu! " \
		--menu "" 19 40 12              \
			"1" "Option One" 			\
			"2" "Option Two"			\
			"3" "Option Three"			\
			"4" "Option Four"			\
2>temp
Cancelled=$?
Choice=`cat  temp` ; rm temp
if [ $Cancelled -eq  0 ];
	then echo "You selected: $Choice"
	else echo "You cancelled!"
fi
