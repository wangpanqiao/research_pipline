#!/usr/bin/perl -w
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use FindBin qw($Bin $Script);
use Cwd qw(realpath fast_abs_path);
use File::Basename qw(basename dirname);
my $BEGIN_TIME=time();
my $version="1.0.0";

# ----------------------------------------------------------
# GetOptions
# ----------------------------------------------------------
my ($degdir,$count,$fpkm,$anno,$gene_name,$cfg,$target,$out,$host,$type,$rnatype);

GetOptions(
        "degdir:s" => \$degdir,
	"count:s" => \$count,
	"fpkm:s" => \$fpkm,
	"host:s" => \$host,
        "anno:s" => \$anno,
        "gnfile:s"=>\$gene_name,
        "cfg:s"=>\$cfg,
	"target:s"=>\$target,
	"type:s"=>\$type,
        "out:s"=>\$out,
        "help|?" => \&USAGE,
) or &USAGE;
&USAGE unless ($degdir and $count and $fpkm and $anno and $host and $cfg and $target and $type and $out);

$degdir = &realpath($degdir);
$count = &realpath($count);
$fpkm = &realpath($fpkm);
$host = &realpath($host);
$target = &realpath($target);
$anno = &realpath($anno);

my %detail_cfg=&detail_cfg_read($cfg);

my %full_table_hash;
my @table_field;
my %id_name;
my %pathway_ko;
&log_current_time("$Script start...");

# ----------------------------------------------------------
# load cfg
# ----------------------------------------------------------
$rnatype="circRNA";

$detail_cfg{"$rnatype.Method_RE"}||="DESeq";
$detail_cfg{"$rnatype.Method_NR"}||="EBSeq";
$detail_cfg{"$rnatype.Method_RE"}=~s/DEseq/DESeq/g;
$detail_cfg{"$rnatype.Method_NR"}=~s/EBseq/EBSeq/g;
my $fdr;
# load gene name
# ----------------------------------------------------------
if (defined $gene_name) {
   open NAME, $gene_name or die $!;
   while (<NAME>) {
    chomp;
    next if (/^#/);
    my @line = split /\t/,$_;
    $id_name{$line[0]}=$line[1];
   }
   close NAME;
}
# ----------------------------------------------------------
# load lncRNA target gene
# ----------------------------------------------------------
my %tmiRNA;
open (MIRNA,$target) or die $!;
while(<MIRNA>){
	chomp;
	next if (/^#/);
	my ($miRNA,$circ)=split /\t/,$_,2;
	my @circRNA = split /;|,/,$circ;
	foreach my $c (@circRNA){
		if(defined $tmiRNA{$c}){
			$tmiRNA{$c}.=";".$miRNA;
		}else{
			$tmiRNA{$c}=$miRNA;
		}
	}
}


my %Tar;
open(Host,$host) or die $!;
while (<Host>) {
    chomp;
    next if (/^#/ || /^$/ || /^circRNA_ID/);
    my @a=split /\t/,$_;
    my @tem=split /;|,/,$a[-1];
    foreach my $gene (@tem){
        $Tar{$a[0]}{$gene}=1;
    }
}
close Host;
# ----------------------------------------------------------
# load expresion value
# ----------------------------------------------------------

my %EXP;
my @sample;
open(COUNT,$count) or die $!;
while (<COUNT>) {
    chomp;
    my @tem=split /\t/,$_;
    my $gene_id=$tem[0];
    if (/^#|^circRNA_ID/) {
        my ($gene_id ,$sam)=split /\t/,$_,2;
        @sample =split /\t/,$sam;pop @sample;
        foreach (my $i=0;$i<@sample;$i++){
          my $sample_count=$sample[$i]."_count";
          my $sample_fpkm=$sample[$i]."_$type";
          my $sample_id=$sample_count."\t".$sample_fpkm;
          push @table_field,$sample_id;
       }
	next;
    }
    foreach (my $i=0;$i<@sample;$i++){
        $EXP{$gene_id}{$sample[$i]}{count}=$tem[$i+1];
    }
}
#print Dumper(\@sample);
open(FPKM,$fpkm) or die $!;
while (<FPKM>) {
    chomp;
    my @tem=split /\t/,$_;
    my $gene_id=$tem[0];
    next if (/^#/ || /^$/);
    foreach (my $i=0;$i<@sample;$i++){
        $EXP{$gene_id}{$sample[$i]}{fpkm}=$tem[$i+1];
    }
}
foreach my $gene (sort keys %EXP) {
    foreach (my $i=0;$i<@sample;$i++){
        my $sample_count=$sample[$i]."_count";
        my $sample_fpkm=$sample[$i]."_$type";
        my $sample_id=$sample_count."\t".$sample_fpkm;
        my $fpkm=$EXP{$gene}{$sample[$i]}{fpkm};
        my $count=$EXP{$gene}{$sample[$i]}{count};
        $full_table_hash{$gene}{$sample_id} = $count."\t".$fpkm;
    }
    
}

# ----------------------------------------------------------
# load DEG
# ----------------------------------------------------------
my @deg_file = glob "$degdir/*vs*/*.all";
if ($#deg_file ==-1) {
    die "deg dir have 0 DEG file !!";
}

for my $file (@deg_file) {
    #print "$file\n";
    basename($file) =~/(\S+_vs_\S+)\.all/;
    my $set_id = $1;
    my (@num)=$set_id=~/(_)/g;
    my $num=@num;
    my $soft;my $thre;
    if ($num==2) {
        $soft=$detail_cfg{"$rnatype.Method_NR"};
    }else{
        $soft=$detail_cfg{"$rnatype.Method_RE"};
    }
   
    my $fdr_index=0;
    my $fc_index=0;
    my $re_index=0;
    my $fact;
    if (-f dirname($file)."/$set_id.DEG_final.xls"){
        open (DEG, dirname($file)."/$set_id.DEG_final.xls") or die $!;
        while (<DEG>) {
            chomp;

            if ($_=~/^#/) {
                my @head=split /\t/,$_;
                $fdr_index=(grep {$head[$_] =~ m/FDR|PValue/} 0..$#head)[0]-1;
		$fact = $head[$fdr_index+1];
                print "Your Screening threshold is: \"$fact\"\n";
                $fc_index=(grep {$head[$_] =~ m/log2FC/} 0..$#head)[0]-1;
                $re_index=(grep {$head[$_] =~ m/regulated/} 0..$#head)[0]-1;
		
            
            if(!exists $detail_cfg{"$rnatype.FDR"} and !exists $detail_cfg{"FDR"} and exists $detail_cfg{"$rnatype.PValue"}){
                $thre = "PValue";
                $fdr = $detail_cfg{"$rnatype.PValue"};
            }else{
                $thre = "FDR";
                $fdr = $detail_cfg{"$rnatype.FDR"};
            }
	    push @table_field,("${set_id}_${soft}_${thre}", "${set_id}_${soft}_log2FC", "${set_id}_${soft}_(${thre}_${fdr}_FC_$detail_cfg{fold})_regulated");
	    print "The threshold that you set in your detail.cfg is: \n";
            print "\"software\" - \"$soft\"\t==";
            print "\"FC\" - \"$detail_cfg{\"$rnatype.fold\"}\"\t==";
            print "\"$thre\" - \"$fdr\"\n";
	    if($soft=~m/EBSeq/i && ($fact=~m/PValue/i || $thre =~m/PValue/i)){
                print "Attention:EBSeq can not generate Pvalue,please check you parameters\n";
            }
	    if($thre ne $fact){
                        print "Attention::Your Screening threshold \"$fact\"is not the same as the value \"$thre\" that you set in your detail.cfg\n";
                        die;
            }
            next;
	    }
	    my @lines = split /\s+/,$_;
            my $gene_id=shift @lines;
            next if (exists $full_table_hash{$gene_id}{"${set_id}_${thre}"});
            $full_table_hash{$gene_id}{"${set_id}_${soft}_${thre}"}       = $lines[$fdr_index];
            $full_table_hash{$gene_id}{"${set_id}_${soft}_log2FC"}    =  $lines[$fc_index];
            $full_table_hash{$gene_id}{"${set_id}_${soft}_(${thre}_${fdr}_FC_$detail_cfg{\"$rnatype.fold\"})_regulated"} = $lines[$re_index];
	
        }
        close DEG;
    }


    if (-f $file) {
        open (DE, $file) or die $!;
        my $fdr_index=0;
        my $fc_index=0;
        my $re_index=0;
        while (<DE>) {
            chomp;    
            if (/^#/ ) {
                my @head=split /\s+/,$_;
                $fdr_index=(grep {$head[$_] =~ m/$thre/} 0..$#head)[0]-1;
                $fc_index=(grep {$head[$_] =~ m/log2FC/} 0..$#head)[0]-1;
                
            }
            #print "$fdr_index\t$fc_index\n";
            next if (/^\s*$/ || $.==1 || /^\#/);
            my @lines = split /\s+/,$_;
	    my $gene_id=shift @lines;
            next if (exists $full_table_hash{$gene_id}{"${set_id}_${soft}_${thre}"});
            $full_table_hash{$gene_id}{"${set_id}_${soft}_${thre}"} = $lines[$fdr_index];
            $full_table_hash{$gene_id}{"${set_id}_${soft}_log2FC"} = $lines[$fc_index];
            $full_table_hash{$gene_id}{"${set_id}_${soft}_(${thre}_${fdr}_FC_$detail_cfg{\"$rnatype.fold\"})_regulated"} = "normal";
        }
        close DE;
    }
}

#print Dumper(\%full_table_hash);
# ----------------------------------------------------------
# load function annotation
# ----------------------------------------------------------
my $anno_file = $anno;
my @anno_field;
my %Anno;
open (ANNO, $anno_file) or die $!;
my $num_anno;
while (<ANNO>) {
    chomp;
    next if (/^\s*$/);
    my ($gene_id, @anno_col) = (split /\t/);

    if ($.==1) {
	for my $tmp (@anno_col){
		if($tmp=~/swiss/i){
			$tmp=~s/-/_/;
			push @anno_field,$tmp;
		}else{
			push @anno_field,$tmp;
		}
	}
        #@anno_field = @anno_col;
        $num_anno=@anno_field;
        #push @table_field, @anno_field;
    } else {
        for (my $i=0; $i<@anno_col; $i++) {
            $Anno{$gene_id}{$anno_field[$i]} = $anno_col[$i];
        }
    }
}

close ANNO;

#print Dumper(\%full_table_hash);
# ----------------------------------------------------------
# output 
# ----------------------------------------------------------

open (OUT, ">$out") or die $!;
print OUT "#ID\tHost_gene_ID\tHost_gene_name\tTarget_miRNA\t".(join "\t",@table_field)."\t".join( "\t",@anno_field)."\n";
for my $l (sort keys %full_table_hash) {
    my $line = "";
    my @targene= sort keys %{$Tar{$l}};
    my $num=@targene;
    if ($num==0) {
        $line="$l\t--\t--";
        for my $c (@table_field) {
            if (exists $full_table_hash{$l}{$c}) {
                $line.= "\t$full_table_hash{$l}{$c}";
            }else {
                $line.= "\t--";
            }
        }
        $line.="\t--"x$num_anno;
        print OUT "$line\n";
    }
    if ($num>=1) {
        my $name;my $tarmiRNA;
	if (exists $tmiRNA{$l}){
		$tarmiRNA = $tmiRNA{$l};
	}else{
		$tarmiRNA = "--";
	}
        foreach my $g (@targene){
		if(defined "$gene_name"){
                	if (exists $id_name{$g}) {
	                    $name=$id_name{$g};
        	        }else{
                	    $name= "--";
                	}
		}else{
			$name= "--";
		}
            $line="$l\t$g\t$name\t$tarmiRNA";
            for my $c (@table_field) {
                if (exists $full_table_hash{$l}{$c}) {
                    $line.= "\t$full_table_hash{$l}{$c}";
                } else {
                    $line.= "\t--";
                }
            }
            for my $c (@anno_field) {
                if (exists $Anno{$g}{$c}) {
                    $line.= "\t$Anno{$g}{$c}";
                } else {
                    $line.= "\t--";
                }
            }
            print OUT "$line\n";
        }
    }
}

close OUT;
# finish log
my $elapse_time = (time()-$BEGIN_TIME)."s";
&log_current_time("$Script done. Total elapsed time: $elapse_time.");
# ----------------------------------------------------------
# sub function
# ----------------------------------------------------------
##############################################################################################################
sub log_current_time {
     # get parameter
     my ($info) = @_;

     # get current time with string
     my $curr_time = date_time_format(localtime(time()));

     # print info with time
     print "[$curr_time] $info\n";
}

##############################################################################################################
sub date_time_format {
    my ($sec, $min, $hour, $day, $mon, $year, $wday, $yday, $isdst)=localtime(time());
    return sprintf("%4d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $day, $hour, $min, $sec);
}

sub detail_cfg_read {
    my %detail_cfg=();

    $rnatype = "circRNA";
    open (CFG,$cfg) or die "$!: $cfg\n";
    while (<CFG>) {
        chomp;
        next if (/^\s+$/ or /^#/ or /^\s+/);
        my ($key, $value) = (split /\s+/)[0,1];
        next unless(defined $key);
        $detail_cfg{$key} = $value;
	
    }
    close CFG;
    my @para = ("Method_RE","Method_NR","fold","FDR","PValue");
    foreach my $pa (@para){
	if(exists $detail_cfg{$pa} && !exists $detail_cfg{"$rnatype.$pa"}){
		$detail_cfg{"$rnatype.$pa"}= $detail_cfg{$pa};
	}
    }
    return %detail_cfg;
}


##############################################################################################################
sub USAGE {
    my $usage=<<"__USAGE__";
#------------------------------------------------------------------------------------
Program: $Script
Version: $version
Contact: songmm <songmm\@biomarker.com.cn>
Data: 2016-10-08
Fuction: the script is used to ...
  Usage:
         perl $Script -degdir ./DEG_Analysis/circRNA -count All_circRNA_count.list -fpkm All_circRNA_expression.list -out wholetrans_circRNA_full_table.xls --anno Integrated_Function.annotation.xls  --gnfile id_name.list -host All_gene_counts_detail.xls -target miRNA-circRNA.mir2target.list --cfg detail.cfg -type SRPBM/TPM
Options:
         -degdir  <dir>       DEG_Analysis/  (contain *vs*/*DEG*final.xls *vs*/*.all),forced
	 -count  <file>       All_circRNA_count.list,forced
	 -fpkm  <file>	      All_circRNA_expression.list,forced
         -host   <file>       All_gene_counts_detail.xls,forced
	 -target <file>	      miRNA-circRNA.mir2target.list,forced
         -anno  <file>        Allgene_Anno/Result/Integrated_Function.annotation.xls,forced
         -out  <dir>          wholetrans_circRNA_full_table.xls,forced
         -gnfile  <file>      gene_name file,/share/nas2/database/genome/*/*/id_name.list; choice;
         -cfg  <file>         detail.cfg,forced
	 -type <str>	      circRNA:SRPBM/TPM
         -help                shown this docment and exit

#------------------------------------------------------------------------------------
__USAGE__
    print $usage;
    exit;
}
