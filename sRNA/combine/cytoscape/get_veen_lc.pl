#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use FindBin qw($Bin $Script);
use File::Basename qw(basename dirname);
use newPerlBase;
use Cwd qw(abs_path getcwd);
my $BEGIN_TIME=time();
my $version="1.0.0";
#######################################################################################
#
#######################################################################################
# ------------------------------------------------------------------
# GetOptions
# ------------------------------------------------------------------
my ($idir,$odir,$cfg,$l2mc,$l2mt,$chostgene);

GetOptions(
				"help|?" =>\&USAGE,
				"od:s"=>\$odir,
				"in:s"=>\$idir,
				"cfg:s"=>\$cfg,
				"l2mc:s"=>\$l2mc,
				"l2mt:s"=>\$l2mt,
				"chostgene:s"=>\$chostgene,
				) or &USAGE;
&USAGE unless ($idir and $cfg);
# ------------------------------------------------------------------
$odir||="./";
$cfg = abs_path($cfg);
$idir = abs_path($idir);
`mkdir $odir` unless (-d "$odir");
$odir = abs_path($odir);

$l2mc||="$idir/Cis_target_gene.xls";
$l2mt||="$idir/Trans_target_gene.xls";
$chostgene||="$idir/circRNA.source.xls";

my %sample = &relate($cfg);
my @diff;my %vs;
open (CFG,"$cfg") or die $!;
print ("read cfg and diff group is:");
while (<CFG>){
	chomp;
	next if(/^#|^$|^\s$/);
	my @tmp = split /\s+/,$_;
	if($tmp[0] eq "Diff"){
		push @diff,$tmp[1];
		print "$tmp[1]\n";
	}
}
close(CFG);

my (%l2m,%m2l,%mi2l,%l2mi,%mi2c,%c2mi,%mi2g,%g2mi,%c2g,%g2c);

###read lncRNA2mRNA file and then get %l2m and %m2l
print ("1:L2M...... %l2m,%m2l\n");
open (L2MC,"$l2mc") or die $!;
while(<L2MC>){
	chomp;
	next if(/^#|^\s$/);
	my @A = split /\t/,$_;
	my @B = split /\;|,/,$A[1];
	my $nm = join (";",@B);
	$l2m{$A[0]}{Cis}=$nm;
	for (my $i=0;$i<@B;$i++){
		if(exists $m2l{$B[$i]}{Cis}){
			$m2l{$B[$i]}{Cis} .= ";".$A[0];
		}else{
			$m2l{$B[$i]}{Cis} = $A[0];
		}
	}
}
if(-e $l2mt){
	open (L2MT,"$l2mt") or die $!;
	while (<L2MT>){
		chomp;
		next if(/^#|^\s$/);
		my @A = split /\t/,$_;
                my @B = split /\;|,/,$A[1];
               	my $nm = join (";",@B);
       	        $l2m{$A[0]}{Trans}=$nm;
                for (my $i=0;$i<@B;$i++){
               	        if(exists $m2l{$B[$i]}{Trans}){
       	                        $m2l{$B[$i]}{Trans} .= ";".$A[0];
                        }else{
                               	$m2l{$B[$i]}{Trans} = $A[0];
                       	}
               	}
	}
}



###read circRNA hostgene file
if(-e "$chostgene"){
	print ("5:C2G...... %c2g,%g2c\n");
	open (C2G,"$chostgene") or die $!;
	while (<C2G>){
		chomp;
		next if(/^#|^$/);
		my @A = split /\t/,$_;
		my @B = split /\;|,/,$A[1];
		my $nm = join (";",@B);
		$c2g{$A[0]}=$nm;
		for (my $i=0;$i<@B;$i++){
			if(exists $g2c{$B[$i]}){
				$g2c{$B[$i]} .= ";".$A[0];
			}else{
				$g2c{$B[$i]} = $A[0];
			}
		}
	}
	close(C2G);
}
print ("read target file progress finish!!!\n\n");

print "get diff result file and creat hash\n\n";
print "#group\tRNA_type\tdiff_files\n";
my (%h,%hash);
foreach my $vs(@diff){
	&switch($vs);
	foreach my $k ("lncRNA","circRNA","gene"){
		$h{$vs}{$k} = "$idir/$k.$vs{$vs}{$k}.DEG_final.xls";
		print "$vs\t$k\t$h{$vs}{$k}\n";
	}
}

print "\n%h===>\$hash{\$deg}{\$trans}{\$id}=\$regulate\n\n";
foreach my $deg (keys %h){
	foreach my $trans(keys %{$h{$deg}}){
		open (IN,"$h{$deg}{$trans}");
		while (<IN>){
			chomp;
			next if(/^#/);
			my @a = split /\t/,$_;
			my $info = $a[0]."(".$a[-1].")";
			$hash{$deg}{$trans}{$a[0]}=$info;
		}
		close(IN);
	}
}
###################lncRNA core#############################
print "core-lncRNA\n";
`mkdir $odir/lncRNA` unless (-d "$odir/lncRNA");
my $lncdir = "$odir/lncRNA";
foreach my $lnc (keys %h){
	open (IN,"$h{$lnc}{lncRNA}");
	my (@A,@B,@C,@D,%tmp,%tmp1,%tmp2);
	while(<IN>){
		chomp;
		next if(/^#/);
		my @a = split;
		push @A,$a[0];
	}
	close (IN);
	open (IN,"$h{$lnc}{gene}");
	while(<IN>){
		chomp;
		next if(/^#/);
		my @a = split;
		if(exists $m2l{$a[0]}{Cis}){
			my @t = split /\;/,$m2l{$a[0]}{Cis};
			for (my $i=0;$i<@t;$i++){
				if(!exists $tmp{$t[$i]}){
					push @B,$t[$i];
					$tmp{$t[$i]}=1;
				}
			}
		}
		if (exists $m2l{$a[0]}{Trans}){
			my @t = split /\;/,$m2l{$a[0]}{Trans};
			for (my $i=0;$i<@t;$i++){
				if(!exists $tmp1{$t[$i]}){
					push @C,$t[$i];
					$tmp1{$t[$i]}=1;
				}
			}
		}
	}
	close (IN);
	my (@list1,@list2,@name1,@name2);
	if(scalar(@A)>=1){push @list1,[@A];push @list2,[@A];push @name1,"DE_LncRNA";push @name2,"DE_LncRNA";}
	if(scalar(@B)>=1){push @list1,[@B];push @name1,"DE_Cis.mRNA_TargetLncRNA";}
	if(scalar(@C)>=1){push @list2,[@C];push @name2,"DE_Trans.mRNA_TargetLncRNA";}
#	my @list1 = ("@A","@B","@D");
#	my @list2 = ("@A","@C","@D");
#	my @name1 = ("DE_LncRNA","DE_Cis.mRNA_TargetLncRNA","DE_miRNA_TargetLncRNA");
#	my @name2 = ("DE_LncRNA","DE_Trans.mRNA_TargetLncRNA","DE_miRNA_TargetLncRNA");
	if(scalar(@list1)>=2){
		&Veen(\@list1,"$lncdir/$lnc.Cis",\@name1);
	}
	if(scalar(@list2)>=2){
		&Veen(\@list2,"$lncdir/$lnc.Trans",\@name2);
	}
}

print "core-circRNA\n";
`mkdir $odir/circRNA` unless (-d "$odir/circRNA");
my $circdir = "$odir/circRNA";
foreach my $circ (keys %h){
        open (IN,"$h{$circ}{circRNA}");
        my (@A,@B,@C,%tmp,%tmp1);
        while(<IN>){
                chomp;
                next if(/^#/);
                my @a = split;
                push @A,$a[0];
        }
        close (IN);
        open (IN,"$h{$circ}{gene}");
        while(<IN>){
                chomp;
                next if(/^#/);
                my @a = split;
                if(exists $g2c{$a[0]}){
                        my @t = split /\;/,$g2c{$a[0]};
                        for (my $i=0;$i<@t;$i++){
                                if(!exists $tmp{$t[$i]}){
                                        push @B,$t[$i];
                                        $tmp{$t[$i]}=1;
                                }
                        }
                }
        }
        close (IN);
	my (@list1,@name1);
	if(scalar(@A)>=1){push @list1,[@A];push @name1,"DE_circRNA";}
	if(scalar(@B)>=1){push @list1,[@B];push @name1,"DE_Hostgene_circRNA";}
#        my @list1 = ("@A","@B","@C");
#        my @name1 = ("DE_circRNA","DE_Hostgene_circRNA","DE_miRNA_TargetcircRNA");
	if(@list1>=2){
		&Veen(\@list1,"$circdir/$circ",\@name1);
	}
}

print "core-mRNA\n";
`mkdir $odir/gene` unless (-d "$odir/gene");
my $gdir = "$odir/gene";
foreach my $g (keys %h){
        open (IN,"$h{$g}{gene}");
        my (@A,@B,@C,@D,@E,%tmp,%tmp1,%tmp2,%tmp3);
        while(<IN>){
                chomp;
                next if(/^#/);
                my @a = split;
                push @A,$a[0];
        }
        close (IN);
        open (IN,"$h{$g}{lncRNA}");
        while(<IN>){
                chomp;
                next if(/^#/);
                my @a = split;
                if(exists $l2m{$a[0]}{Cis}){
                        my @t = split /\;/,$l2m{$a[0]}{Cis};
                        for (my $i=0;$i<@t;$i++){
                                if(!exists $tmp{$t[$i]}){
                                        push @B,$t[$i];
                                        $tmp{$t[$i]}=1;
                                }
                        }
                }
		if(exists $l2m{$a[0]}{Trans}){
                        my @t = split /\;/,$l2m{$a[0]}{Trans};
                        for (my $i=0;$i<@t;$i++){
                                if(!exists $tmp1{$t[$i]}){
                                        push @C,$t[$i];
                                        $tmp1{$t[$i]}=1;
                                }
                        }
                }
        }
        close (IN);
	open(IN,"$h{$g}{circRNA}");
        while(<IN>){
                chomp;
                next if(/^#/);
                my @a = split;
                if(exists $c2g{$a[0]}){
                        my @t = split /\;/,$c2g{$a[0]};
                        for (my $i=0;$i<@t;$i++){
                                if(!exists $tmp3{$t[$i]}){
                                        push @E,$t[$i];
                                        $tmp3{$t[$i]}=1;
                                }
                        }
                }
        }
        close(IN);
	my (@list1,@list2,@name1,@name2);
	if(scalar(@A)>=1){push @list1,[@A];push @list2,[@A];push @name1,"DE_mRNA";push @name2,"DE_mRNA";}
	if(scalar(@B)>=1){push @list1,[@B];push @name1,"DE_LncRNA_Target.CismRNA";}
	if(scalar(@C)>=1){push @list2,[@C];push @name2,"DE_LncRNA_Target.TransmRNA";}
	if(scalar(@E)>=1){push @list1,[@E];push @list2,[@E];push @name1,"DE_circRNA_Hostgene";push @name2,"DE_circRNA_Hostgene";}
#       my @list1 = ("@A","@B","@D","@E");
#	my @list2 = ("@A","@C","@D","@E");
#       my @name1 = ("DE_mRNA","DE_LncRNA_Target.CismRNA","DE_miRNA_TargetmRNA","DE_circRNA_Hostgene");
#	my @name2 = ("DE_mRNA","DE_LncRNA_Target.TransmRNA","DE_miRNA_TargetmRNA","DE_circRNA_Hostgene");
	if(scalar(@list1)>=2){
	        &Veen(\@list1,"$gdir/$g.Cis",\@name1);
	}
	if(scalar(@list2)>=2){
		&Veen(\@list2,"$gdir/$g.Trans",\@name2);
	}
}

#######################################################################################
print STDOUT "\nDone. Total elapsed time : ",time()-$BEGIN_TIME,"s\n";
#######################################################################################

# ------------------------------------------------------------------
# sub function
# ------------------------------------------------------------------
################################################################################################################
sub relate{
        my $cfg=shift;
        my %sample=();
        my @rnas=();
        open(CFG,$cfg)||die $!;
        while(<CFG>){
                chomp;next if($_!~/^Sample/);
                my @tmp=split(/\s+/,$_);shift @tmp;
                if($tmp[0] eq "ID" && scalar(@rnas)==0){
                        shift @tmp;@rnas=@tmp;
                }else{
                        my $id=shift @tmp;
                        for(my $i=0;$i<@tmp;$i++){
                                $sample{$id}{$rnas[$i]}=$tmp[$i];
                        }
                        $sample{$id}{gene}=  $sample{$id}{lncRNA} if(exists $sample{$id}{lncRNA} && !exists $sample{$id}{gene});
                }
        }
        close(CFG);
        return %sample;
}

sub switch {
	my $group = shift;
	my ($v1,$v2,@V1,@V2);
	
		($v1,$v2) = split /_vs_/,$group,2;
		@V1 = split /_/,$v1;
		@V2 = split /_/,$v2;
		foreach my $key ("sRNA","lncRNA","circRNA","gene"){
			my (@s1,@s2);
			for(my $i=0;$i<@V1;$i++){
				push @s1,$sample{$V1[$i]}{$key};
			}
			for(my $j=0;$j<@V2;$j++){
				push @s2,$sample{$V2[$j]}{$key};
			}
			my $S1 = join ("_",@s1);
			my $S2 = join ("_",@s2);
			my $Group = join("_vs_",$S1,$S2);
			$vs{$group}{$key}=$Group;
		}
}

sub Veen{
	my ($List,$name,$id)=@_;
	my $dir = dirname $name;
	my $prefix = basename $name;
	my (%info,%venny, %com);
	open (SET, ">$name.degset.xls") or die $!;
	print SET "#DEG_Set\tDEG_Num\tDEG_IDs\n";
	my @label =@$id;
	my @list =@$List;
	for my $i (1..($#list+1)){
		my @ids = @{$list[$i-1]};
		for (my $j=0;$j<@ids;$j++){
			my $deg_id = $ids[$j];
			$info{$deg_id}{$label[$i-1]} = 1;
		}
		my ($id_num,$ids) = ($#ids+1, (join ";",@ids));
		print SET "$label[$i-1]\t$id_num\t$ids\n";
	}

	close SET;
	for my $e (sort keys %info) {
		my $com = join ",",(sort keys %{$info{$e}});
		$com{$com}++;
		$venny{$com}{$e} = 1;
	}
	open (VENN, ">$name.vennset.xls");
	print VENN "#Venn_Set\tElement_Num\tElement_IDs\n";

	for my $s (sort keys %venny) {
		my $elements = join ";",(sort keys %{$venny{$s}});
		print VENN "$s\t$com{$s}\t$elements\n";
	}
	my @color=("'cornflowerblue'","'green'","'yellow'","'darkorchid1'","'red'");
	my %DEG;
	my $list_content;
	my $label_content;
	my $color_content;
	for my $i (1..($#list+1)) {
		my @id=@{$list[$i-1]};
		for(my $j=0;$j<@id;$j++){
			my $deg_id = "'".$id[$j]."'";
			push @{$DEG{$label[$i-1]}}, $deg_id;
		}
	}
	my @name=qw(A B C D E F G M);
	my $name_content;
	for my $i (0..@label-1) {
		$list_content.= "$name[$i] <- c(".(join ", ",@{$DEG{$label[$i]}}).")\n";
		$label_content.= "$name[$i] = $name[$i], ";
		$name_content.="\"$label[$i]\",";
		$color_content.= "$color[$i], ";
	}
	$list_content =~ s/\n$//;
	$label_content =~ s/, $//;
	$color_content =~ s/, $//;
	$name_content=~s/,$//;
	my $more_opts = "";
	if (@label == 5) {
		$more_opts.= "    cex = 0.5,\n";
		$more_opts.= "    cat.cex = 0.6,\n";
		$more_opts.= "    margin = 0.1,\n";
		$more_opts.= "    cat.dist = c(0.20, 0.25, 0.20, 0.20, 0.25),\n";
		$more_opts.= "    scaled = FALSE,\n";
	}
	elsif (@label == 4) {
		$more_opts.= "    cex = 0.6,\n";
		$more_opts.= "    cat.cex = 0.7,\n";
		$more_opts.= "    margin = 0.08,\n";
		$more_opts.= "    scaled = FALSE,\n";
	}
	elsif (@label == 3) {
		$more_opts.= "    cex = 0.7,\n";
		$more_opts.= "    cat.cex = 0.7,\n";
		$more_opts.= "    margin = 0.06,\n";
		$more_opts.= "    euler.d = FALSE,\n";
		$more_opts.= "    cat.pos = c(0,0,180),\n";
		$more_opts.= "    scaled = FALSE,\n";
	}
	elsif (@label == 2) {
		$more_opts.= "    cex = 0.8,\n";
		$more_opts.= "    cat.cex = 0.5,\n";
		$more_opts.= "    margin = 0.05,\n";
		$more_opts.= "    cat.pos = 180,\n";
		$more_opts.= "    euler.d = TRUE,\n";
		$more_opts.= "    scaled = FALSE,\n";
	}
my $R_script = << "EOF";
#!/share/nas2/genome/biosoft/R/3.1.1/lib64/R/bin/Rscript
#import library
library(grid)
library(VennDiagram)
#init deg lists
$list_content
lst=list($label_content)
names(lst)=c($name_content)
#plot venn
venn.diagram(
	x = lst,
	filename = "$prefix.venn.png",
	imagetype = "png",
	fill = c($color_content),
	height=1300,
	width=1300,
	resolution=200,
	units='px',
	wd=1,
	$more_opts
);
	
EOF
	open (RS, ">$name.venn.r") or die;
		print RS $R_script;
	close RS;

	`cd $dir && /share/nas2/genome/biosoft/R/3.1.1/bin/Rscript $name.venn.r`;
}

################################################################################################################

sub GetTime {
	my ($sec, $min, $hour, $day, $mon, $year, $wday, $yday, $isdst)=localtime(time());
	return sprintf("%4d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $day, $hour, $min, $sec);
}

################################################################################################################
sub USAGE {
	my $usage=<<"USAGE";
 ProgramName:
     Version:	$version
     Contact:	Niepy <niepy\@biomarker.com.cn> 
Program Date:	2018.05.23
      Modify:	
 Description:	This program is used to .... 
       Usage:
		Options:
		-in <dir>	input dir ,DEG_Analysis,force
		-od <dir>	output dir , Combine/Cytoscape,force
		-cfg <file>	cfg,force
		-l2mc <file>	Cis target file, (l2mc and l2mt) can exist with l2m at the same time.
		-l2mt <file>	Trans target file, l2mt can not exist 
		-chostgene <file>	circRNA hostgene file
		-h		help

USAGE
	print $usage;
	exit;
}