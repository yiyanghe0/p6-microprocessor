#!/bin/bash

FILES=/home/xunhan/Desktop/470/project4/group5w23/test_progs/*
ORI_FILES=/home/xunhan/Desktop/470/project3_ori/test_progs/*
ORI_WB_FILES=/home/xunhan/Desktop/470/project3_ori/output/*.wb
#ground truth
#for file in ${ORI_FILES}; do
#	file=$(echo $file | cut -d'.' -f1)
#	file=$(echo $file | cut -c 50-67)	
#	echo $file
#	make $file.out
#done

#modified pipeline
for file in ${FILES}; do
	file=$(echo $file | cut -d'.' -f1)
	file=$(echo $file | cut -c 56-70)	
	#echo $file
	make $file.out
done

#compare .wb .out files
for file in ${ORI_WB_FILES}; do
	file=$(echo $file | cut -d'.' -f1)
	file=$(echo $file | cut -c 46-63)	
#	echo $file
	wb_check=$(diff /home/xunhan/Desktop/470/project3_ori/output/$file.wb /home/xunhan/Desktop/470/project4/group5w23/output/$file.wb)
	out_check=$(diff /home/xunhan/Desktop/470/project3_ori/output/$file.out /home/xunhan/Desktop/470/project4/group5w23/output/$file.out | grep "@@@")
	#echo $wb_check
	echo $out_check
	if [ "$wb_check" ] 
		then echo "@@@case failed at .wb"
	else echo "@@@case succeed"
	fi 

if [ "$out_check" ] 
		then echo "@@@case failed at .out"
	else echo "@@@case succeed"
	fi 
done


	

