################################   IMPORTANT NOTE  ##################################
#DO NOT keep def and design data in the directory where this script is being run
#Script deletes existing verilog def and some tcl files (search for rm -rf command)
#It is best to run script in empty directory as it will create all the required files
#Authors are not responsible for any data lost. Use this scipt at your own risk
#Author: Rohit Somwanshi
#####################################################################################

use strict;
use warnings;
use Data::Dumper;

#remove existing files - required as we are opening files in multiple functions to overwrite
system ( ' rm -rf *.def test.tcl ld.tcl ld.v create_what_if.tcl');

#global arrays
my @nets;
my @pwr_nets;
my @gnd_nets;

#this function writes load design and run script files
readConfigFile();

#print analyze_rail after everything
my $fh_end;
open($fh_end, ">> test.tcl") or die("Cannot create file test.tcl");
print $fh_end "analyze_rail \\\n\t-type domain\\\n\t-results_directory ./era_test \\\n\tALL\n\n";
close ($fh_end);


#print " Nets @nets\n";
#print "Power nets @pwr_nets\nGround nets @gnd_nets\n";

sub readConfigFile{
        my $fh;
        open($fh, 'config.txt') or die("Cannot read file config.txt");
        my @data = <$fh>;
        close ($fh);
        my $count = 0;
	my $pkg_read = 0;
        tclHeader ('test.tcl',1);
	foreach my $line (@data) {
        chomp($line);
        $count += 1;

	if($line =~ /^net\s*/){
        	if($line =~ /^(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s*$/){
       			print "\nNet name=$2\nPloc file=$4\nNet type=$3\nNominal voltage=$5\n";
			if ($3 eq "POWER"){
			push @pwr_nets, $2;
			}
			elsif ($3 eq "GROUND"){
			push @gnd_nets, $2;
			}
			else {
			print "ERROR: Net $2 does not have correct POWER/GROUND attribute in config file.\n"
			}
		my $isDef = createDef($2, $4, $3);
			if ( $isDef == 1 ){
			print "Created $2.def file successfully.\n\n";
			push @nets, $2;
			}
		setVoltages($2, $4, $5);
         	}
	}
	
	elsif ($line =~ /^tlef\s*/){
		if($line =~ /^(.*?)\s+(.*?)\s*$/){
		  print "techlef $2\n";
	       	  writeLoadDesign($2);
	  	}
		}
	elsif ($line =~ /^pkg\s*/){
		if($line =~ /^(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s*$/){
		  print "Package model $3\ndie-package mapping $4\n";
		  writeSetPackage($2,$3,$4) 
	  	}
		else {print "ERROR: specify pkg <subckt> <spice model path> <mapping file path>"}
		}
	elsif ($line =~ /^exttech\s*/){
		if($line =~ /^(.*?)\s+(.*?)\s*$/){
		  print "Extraction Tech $2\n";
	       	  railMode($2);
	  	}
		}
	elsif ($line =~ /^pwl\s*/){
		  if($line =~ /^(.*?)\s+(.*?)\s+(.*?)\s*$/){
		  print "PWL $3\n";
		  writeCurRegion($2,$3);
	  	}
		}
	else {print "Config file format is wrong on line $count!\n\n";exit;}
        }
}   

###################### start creating def functions  ######################
sub createDef{
my $net_name = shift;
my $VDD_ploc = shift;
my $net_type = shift;
my $outfile = "$net_name.def";
my %data_db;

writeHeader($outfile,$net_name);
readPlocFile($VDD_ploc, $net_name, $net_type, \%data_db, $outfile);
writeUSE($net_type, $outfile);
writeFooter($net_type, $outfile);

#print Dumper \%data_db;

sub readPlocFile{
	my $ploc = shift;
	my $net_name = shift;
	my $net_type =shift;
	my $ref_data_db =shift;
	my $outfile = shift;
	my $fh;
	open($fh, $ploc) or die("Cannot read file $ploc");
	my @data = <$fh>;
	close ($fh);

	my $count = 0;
	foreach my $line (@data) {
		chomp($line);
	if($line =~ /^\*\s*/)
	{ #print "Comment line\t$line\n";
	}
	else {if($line =~ /^(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s*$/){
	#	print "X=$2\tY=$3\tLayer=$4\n";
	$count += 1;
	#print "$count\n";
		writeDefShape($2,$3,$4,$net_name,$net_type,$count,$outfile);
	   }
	  }
	 }
}

sub writeDefShape{
my $X = shift;
my $Y = shift;
my $layer = shift;
my $net_name = shift;
my $net_type = shift;
my $count = shift;
my $outfile =shift;
	#print "count $count\n";
    my $fh_out;
    open($fh_out, ">> $outfile") or die("Cannot create file $outfile");
	my $X1 = ($X-5)*10000;
	my $X2 = ($X+5)*10000;
	my $Y1 = ($Y-5)*10000;
	my $Y2 = ($Y+5)*10000;

	#add extra shape to go through MG
	my $X_add = $X+12;
	my $Y_add = $Y;
	
	#create def shape for this extra node
	my $X1_add = ($X_add-5)*10000;
	my $X2_add = ($X_add+5)*10000;
	my $Y1_add = ($Y_add-5)*10000;
	my $Y2_add = ($Y_add+5)*10000;

	if($count == 1){
	createWhatIf($X1,$Y1,$X2_add,$Y2_add,$net_name,$layer);
	print $fh_out "  + RECT $layer ( $X1 $Y1 ) ( $X2 $Y2 )\n";
	print $fh_out "  + RECT $layer ( $X1_add $Y1_add ) ( $X2_add $Y2_add )\n";}
	else {
	print $fh_out "  + RECT $layer ( $X1 $Y1 ) ( $X2 $Y2 )\n";}
close ($fh_out);
return 1;
}

sub writeHeader{
    my $outfile =shift;
    my $net_name =shift;
    my $fh_out;
    open($fh_out, ">> $outfile") or die("Cannot create file $outfile");
	print $fh_out "VERSION 5.8 ;\nDIVIDERCHAR \"\/\" ;\nBUSBITCHARS \"[]\" ;\nDESIGN my_chip ; \nUNITS DISTANCE MICRONS 10000 ; \n\n";
	print $fh_out "DIEAREA ( 0 0 ) ( 207000000 207000000 ) ;\n";
	print $fh_out "SPECIALNETS 3 ;\n- $net_name\n";
close ($fh_out);
}

sub writeFooter{
	my $net_type=shift;
	my $outfile =shift;
    my $fh_out;
	open($fh_out, ">> $outfile") or die("Cannot create file $outfile");
	print $fh_out "END SPECIALNETS\nEND DESIGN";
    close ($fh_out);
}

sub writeUSE{
	my $net_type = shift;
	my $outfile =shift;
	my $fh_out;
	open($fh_out, ">> $outfile") or die("Cannot create file $outfile");
	print $fh_out "  + USE $net_type\n;\n";
	close ($fh_out);
}

return 1;
}

############# end creating def functions  ####################################################


sub tclHeader{
my $outfile = shift;
my $source_load_design = shift;
my $fh;
open($fh, ">> $outfile") or die("Cannot create file test.tcl");
my $datestring = localtime();
#header
	print $fh "#" . "-"x75 ."#\n";
	print $fh "#Voltus Package only flow for QC\n";
	print $fh "#DISCLAIMER: Use at your own risk. Feel free to enhance :)\n";
	print $fh "#Author: Rohit Somwanshi\n [03/20/2019]\n#$datestring\n";
	print $fh "#" . "-"x75 ."#\n";
	if($source_load_design == 1){
		print $fh "\n\nsource ld.tcl\n";
		print $fh "\nsource create_what_if.tcl\n\n";}
close ($fh);
}

sub writeSetPackage{
my $subckt = shift;
my $spice = shift;
my $mapping = shift;
my $fh;
open($fh, ">> test.tcl") or die("Cannot create file test.tcl");
	print $fh "set_package \\\n";
	print $fh "-spice $spice -mapping $mapping -subckt $subckt\n\n";
close ($fh);
}

sub createWhatIf {
my $X1 = shift;
my $Y1 = shift;
my $X2 = shift;
my $Y2 = shift;
my $net_name = shift;
my $layer = shift;

my $X1p = $X1/10000;
my $X2p = $X2/10000;
my $Y1p = $Y1/10000;
my $Y2p = $Y2/10000;

my $fh_wi;
open($fh_wi, ">> create_what_if.tcl") or die("Cannot create file create_what_if.tcl");
print $fh_wi "create_what_if_shape -type wire -area {{$X1p $Y1p $X2p $Y2p}} -layer $layer -direction hor -net $net_name -add\n";
close $fh_wi;
}

sub writeCurRegion {
my $layer = shift;
my $pwl = shift;
my $fh;
open($fh, "> curRegion.file") or die("Cannot create file curRegion.file");

print $fh "##################################################\n#Format: LABEL name NET netname AREA x1 y1 x2 y2 LAYER layername <CURRENT value | PWL (t1 i1 t2 i2...)> INTRINSIC_CAP value LOADING_CAP value\n#Unit: current mA, cap pf, time ns, coordinate um\n##################################################\n\n";

foreach my $net (@nets){
print $fh "label for_$net net $net area 0 0 27000 27000 layer $layer pwl ($pwl) intrinsic_cap 10 loading_cap 60\n";
}
}


sub railMode{
my $ext_tech = shift;
my $fh;
open($fh, ">> test.tcl") or die("Cannot create file test.tcl");
	#print set_rail_analysis_mode
	print $fh "\nset_rail_analysis_mode \\\n\t-method era_dynamic \\\n\t-accuracy xd\\\n";
	print $fh "\t-extraction_tech_file $ext_tech \\\n\t-temperature 125 \\\n";
	print $fh "\t-era_current_region_file curRegion.file \\\n";
	print $fh "\t-ignore_incomplete_net false \\\n\t-import_what_if_shapes true\n\n";
	#print dynamic rail simulation
	print $fh "set_dynamic_rail_simulation -reset\n";
	print $fh "set_dynamic_rail_simulation -resolution 50ps -stop 20ns\n\n";
	#print rail domain
	print $fh "set_rail_analysis_domain -name ALL -pwrnets { @pwr_nets } -gndnets { @gnd_nets }\n\n";
close ($fh);
return 1;
}

## this function writes set_pg_nets and set_power_pads for all nets
sub setVoltages{
my $net_name = shift;
my $ploc_file = shift;
my $voltage = shift;

my $fh;
open($fh, ">> test.tcl") or die("Cannot create file test.tcl");
	my $threshold =abs ($voltage - 0.1);
	print $fh "set_pg_nets -net $net_name -voltage $voltage -threshold $threshold\n";
	print $fh "set_power_pads -format xy -file $ploc_file -net $net_name\n\n";
close ($fh);
}


#Write load design script (ld.tcl)
sub writeLoadDesign{
my $tlef =shift;
my $fh;
	open($fh, ">> ld.tcl") or die("Cannot create file ld.tcl");
	tclHeader('ld.tcl',0);
	print $fh "\n#" . "-"x75 ."#";
	print $fh "\n#load design script";
	print $fh "\n#" . "-"x75 ."#\n\n";
	print $fh "set_multi_cpu_usage -localCpu 6\n\n";
	#read tlef
	print $fh "read_lib -lef $tlef\n";
	
	#read verilog and set top module
	#open a new file ld.v to create dummy verilog - it will have my_chip instance - keep it consistent with def top instance
	my $fh_v;
	open($fh_v, ">> ld.v") or die('Cannot create file ld.v');
	print $fh_v "module my_chip()\;\n";
	print $fh_v "endmodule";
	close ($fh_v);
	#print
	print $fh "\nread_verilog ld.v\n";
	print $fh "set_top_module my_chip -ignore_undefined_cell\n";
	
	#read defs of the nets processed in createDef function
	print $fh "read_def ";
	#nets array has list of all nets that has isDef true
	foreach my $net (@nets){
	print $fh "$net.def ";}
	print $fh "\n\n";
close ($fh);
}

