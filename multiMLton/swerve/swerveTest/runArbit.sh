#!/bin/bash

file="index.html"
d="Arbitrator_index"
smallsleep=3
bigsleep=3
numConns=1000
myport=8084
iot=3

resdir="${d}_${numConns}conn_${iot}iot"
rm -r ${resdir}
mkdir ${resdir}
killall -9 main

for proc in 6
do
    directory="${resdir}_${proc}"
    rm -r ${directory}
    mkdir ${directory}

    touch ./${directory}/COLLECT.txt

    echo "Creating swerve for proc = ${proc}"

    echo "hello" > ${HOME}/multiMLton/swerve/swerveArbitrator/www/var/test
    rm ${HOME}/multiMLton/swerve/swerveArbitrator/www/var/*
    ${HOME}/multiMLton/swerve/swerveArbitrator/main/main @MLton number-processors ${proc} enable-timer 15000 io-threads ${iot} fixed-heap 2G -- -f ${HOME}/multiMLton/swerve/swerveArbitrator/www/swerve.cfg &
    sleep ${smallsleep}

    echo "Running httperf..."

    for x in  100 200 300 400 500 600 700 800 900 1000 1100 1200 1300 1400 1500
    do
        echo "rate :: ${x}    directory :: ${directory}"

        httperf --port=${myport} --server=e --rate=${x} --num-conns=${numConns} --num-calls=1 --uri=/${file} --timeout=100 > ./${directory}/session_rate${x}.txt

        echo "HTTPERF RATE ${x} :::" >> ./${directory}/COLLECT.txt

        tail -28 ./${directory}/session_rate${x}.txt >> ./${directory}/COLLECT.txt

        echo "Proc :: ${proc}, Rate :: ${x},Going to sleep.. zzzzzz..."
        sleep ${bigsleep}
        echo "Woke up!!"

    done
    killall -9 main
    perl parse.pl ${directory}/COLLECT.txt ${numConns} > ${resdir}/${directory}.tsv
    rm -r ${directory}
    sleep ${bigsleep}

done
