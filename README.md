# PackageOnlyVoltusFlow

#DO NOT keep def and design data in the directory where this script is being run
#Script deletes existing verilog def and some tcl files (search for rm -rf command)
#It is best to run script in empty directory as it will create all the required files
#Authors are not responsible for any data lost. Use this scipt at your own risk

#How to run:
#perl top.pl
#This file uses config.txt file saved in the same directory

#In config.txt
#1. net <net name as per def> <net type = POWER/GROUND> <power pad file location> <nominal voltage> 
#example: net VDD POWER VDD.pp 0.9
#2. tlef <pointer to tech lef>
#example: /home/rohits/data/lef/file_tech.tlef
#3. exttech <pointer to extraction tech>
#exttech /home/rohits/pdk1_0l.tch
#4. pkg <top subckt> <package model> <mapping file> 
#example: pkg rak_top ./package_dir/simple_pkg.ckt ./package_dir/pkg_mapping.file
#5. pwl <metal layer> t1 I1 t2 I2 t3 I3 ....
#pwl Metal5 0ns 0mA 1ns 0mA 1.9ns 0mA 2ns 10mA 4ns 0mA
  
You will get test.tcl in the end, which can be directly used to run package only test.
