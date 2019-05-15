#!/usr/bin/perl -w
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use FindBin qw($Bin $Script);
use File::Basename qw(basename dirname);
my $BEGIN_TIME=time();
my $version="1.0.0";

#######################################################################################
# ------------------------------------------------------------------
# GetOptions
# ------------------------------------------------------------------
my ($indir);

GetOptions(
                "help|?" =>\&USAGE,
                "in:s"=>\$indir,
                ) or &USAGE;
&USAGE unless ($indir);

$indir = &ABSOLUTE_DIR("$indir");

my $backup_dir = "$indir/Backup";
`rm -r $backup_dir` if(-d "$backup_dir");
`mkdir $backup_dir` unless (-d "$backup_dir");

`cp $indir/work_sh/all.id_name.list $backup_dir/`;
`cp $indir/SNP_Analysis/SNP/*_anno/final.*.anno.gatk.vcf $backup_dir/`;
`cp -r $indir/work_sh $backup_dir`;
###lncRNA###
`mkdir $backup_dir/LncRNA` unless (-d "$backup_dir/LncRNA");
`cp -r $indir/Basic_Analysis/Hisat_Stringtie/Ref_Genome $backup_dir/LncRNA/`;
`cp -r $indir/Basic_Analysis/Hisat_Stringtie/genePredict $backup_dir/LncRNA/`;
`rm -r $backup_dir/LncRNA/genePredict/*_gene`;
`rm -r $backup_dir/LncRNA/genePredict/work_sh/*qsub`;
`rm -r $backup_dir/LncRNA/genePredict/work_sh/*error`;
`cp -r $indir/Basic_Analysis/Hisat_Stringtie/LncPredict $backup_dir/LncRNA/`;
`cp -r $indir/Basic_Analysis/Hisat_Stringtie/prepDE $backup_dir/LncRNA/`;
`mkdir $backup_dir/LncRNA/work_sh`;
`cp -r $indir/Basic_Analysis/LncRNA_Analysis/work_sh/* $backup_dir/LncRNA/work_sh`;
###circRNA###
`mkdir $backup_dir/circRNA` unless (-d "$backup_dir/circRNA");
`cp -r $indir/Basic_Analysis/circRNA_analysis/expression $backup_dir/circRNA`;
`cp -r $indir/Basic_Analysis/circRNA_analysis/new_name $backup_dir/circRNA`;
`mkdir $backup_dir/circRNA/work_sh` unless(-d "$backup_dir/circRNA/work_sh");
`cp $indir/Basic_Analysis/circRNA_analysis/work_sh/*sh $backup_dir/circRNA/work_sh`;
`cp $indir/Basic_Analysis/circRNA_Bwa/Map_Stat/All.readLength.xls $backup_dir/circRNA`;

###miRNA###
`mkdir -p $backup_dir/sRNA/miRDeep2` unless (-d "$backup_dir/sRNA/miRDeep2");
`cp $indir/Basic_Analysis/sRNA_Analysis/miRDeep2/mirdeep_runs/run_*/output.mrd $backup_dir/sRNA/miRDeep2/`;
`cp $indir/Basic_Analysis/sRNA_Analysis/miRDeep2/mirdeep_runs/run_*/tmp/precursors.coords $backup_dir/sRNA/miRDeep2/`;
`cp $indir/Basic_Analysis/sRNA_Analysis/miRDeep2/mirdeep_runs/run_*/tmp/precursors.str $backup_dir/sRNA/miRDeep2/`;
`cp $indir/Basic_Analysis/sRNA_Analysis/miRDeep2/Total_reads_collapsed.fa $backup_dir/sRNA/miRDeep2/`;
`cp $indir/Basic_Analysis/sRNA_Analysis/miRDeep2/Total_reads_collapsed_vs_genome.arf $backup_dir/sRNA/miRDeep2/`;

###target###
`mkdir $backup_dir/Target_Predict` unless (-d "$backup_dir/Target_Predict");
my @rna=("gene","circRNA","lncRNA");
foreach my $rna(@rna){
	`mkdir $backup_dir/Target_Predict/$rna` unless(-d "$backup_dir/Target_Predict/$rna");
	`cp $indir/miRNA_Target/$rna/miRanda.aln.txt $backup_dir/Target_Predict/$rna/` if(-f "$indir/miRNA_Target/$rna/miRanda.aln.txt");
	`cp $indir/miRNA_Target/$rna/targetscan.context.txt $backup_dir/Target_Predict/$rna/` if(-f "$indir/miRNA_Target/$rna/targetscan.context.txt");
	`cp $indir/miRNA_Target/$rna/RNAhybrid.aln_svm.txt $backup_dir/Target_Predict/$rna/` if(-f "$indir/miRNA_Target/$rna/RNAhybrid.aln_svm.txt");
	`cp $indir/miRNA_Target/$rna/TargetFinder.aln.txt $backup_dir/Target_Predict/$rna/` if(-f "$indir/miRNA_Target/$rna/TargetFinder.aln.txt");
}

###DEG_Analysis###
`mkdir $backup_dir/DEG_Analyisis` unless (-d "$backup_dir/DEG_Analyisis");
`cp $indir/DEG_Analysis/*cfg $backup_dir/DEG_Analyisis`;

#######################################################################################
print STDOUT "\nDone. Total elapsed time : ",time()-$BEGIN_TIME,"s\n";
#######################################################################################

sub ABSOLUTE_DIR{ #$pavfile=&ABSOLUTE_DIR($pavfile);
    my $cur_dir=`pwd`;chomp($cur_dir);
    my ($in)=@_;
    my $return="";
    if(-f $in){
        my $dir=dirname($in);
        my $file=basename($in);
        chdir $dir;$dir=`pwd`;chomp $dir;
        $return="$dir/$file";
    }elsif(-d $in){
        chdir $in;$return=`pwd`;chomp $return;
    }else{
        warn "Warning just for file and dir\n";
        exit;
    }
    chdir $cur_dir;
    return $return;
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
     Version:   $version
     Contact:   Yang nan <yangn\@biomarker.com.cn> 
Program Date:   2016.03.08
      Modify:   
 Description:   This program is used to package the zip file to Need_Data......
       Usage:
        Options:
        -in <dir>   input directory,xxx format,forced
        -h      help

USAGE
    print $usage;
    exit;
}
