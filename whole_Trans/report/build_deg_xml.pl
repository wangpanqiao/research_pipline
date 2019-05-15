#!/usr/bin/perl
#use warnings;
use Getopt::Long;
use Getopt::Std;
use Config::General;
use FindBin qw($Bin $Script);
use Cwd qw(abs_path getcwd);
use File::Basename qw(basename dirname);
use XML::Writer;
use IO::File;
use Encode;
my ($cfg,$deg,$density,$type,$output);
GetOptions(
        "h|?"           =>\&USAGE,
	"density:s"	=>\$density,
	"deg:s"		=>\$deg,
	"type:s"	=>\$type,
	"cfg:s"		=>\$cfg,
        "o:s"           =>\$output,
	"cloud"		=>\$cloud,
)or &USAGE;
&USAGE unless ($density and $cfg and $output);

$deg=abs_path($deg);
$density=abs_path($density);
$cfg=abs_path($cfg);
$type||="gene";
my $od=dirname $output;
my %config=&readcfg($cfg);

my $deg_flag =1;
if(!exists $config{Sep} && !exists $config{Com}){
	$deg_flag=0;
}
`mkdir -p $od/$type`	unless(-d "$od/$type");

my $relate_cloud;
if(defined $cloud){
	$relate_cloud = "..";
}else{
	$relate_cloud = "../../";
}

###deg desc
my ($flag,$control,$fold,$FDR,$pvalue,$sep,$com ,$desc);
$fold=$config{"$type.fold"}	if(exists $config{"$type.fold"});
$FDR=$config{"$type.FDR"}	if(exists $config{"$type.FDR"});
$pvalue=$config{"$type.PValue"}	if(exists $config{"$type.PValue"});
$sep=$config{"$type.Method_RE"}	if(exists $config{"$type.Method_RE"});
$com=$config{"$type.Method_NR"}	if(exists $config{"$type.Method_NR"});
$sep||="DEseq";
$com||="EBseq";

$fold||=2;
if(!defined $FDR && !defined $pvalue){
	$control="将|FC|>=$fold 且 FDR<0.01 作为筛选标准";
	$flag="FDR";
}elsif(defined $FDR && defined $pvalue){
	$control="将|FC|>=$fold 且 FDR<$FDR 作为筛选标准";
	$flag="FDR";
}elsif(defined $FDR && !defined $pvalue){
	$control="将|FC|>=$fold 且 FDR<$FDR 作为筛选标准";
	$flag="FDR";
}elsif(!defined $FDR && defined $pvalue){
	$control="将|FC|>=$fold 且 pvalue<$pvalue 作为筛选标准";
	$flag="pvalue";
}

my $demethod="检测差异表达$type时，需要根据实际情况选取合适的差异表达分析软件。";
my ($sep_ref,$com_ref);
if($sep =~/edgeR/i){
	$sep_ref = "$sep<a href=\"#ref1\">[1]</a>";
}
if($sep =~/DEseq/i){
	$sep_ref = "$sep<a href=\"#ref2\">[2]</a>";
}

if($com =~/EBSeq/i){
	$com_ref = "$com<a href=\"#ref3\">[3]</a>";
}
if($com =~/edgeR/i){
	$com_ref = "$com<a href=\"#ref1\">[1]</a>";
}
$demethod.="对于有生物学重复的样品的差异表达分析，采用$sep_ref软件进行差异筛选，$control。";
$demethod.="对于无生物学重复的样品的差异表达分析，采用$com_ref软件进行差异筛选，$control。";
$demethod.="差异倍数（Fold Change，FC）表示两样品（组）间表达量的比值，pvalue为差异表达的显著性，对显著性p值进行校正会得到错误发现率（False Discovery Rate，FDR）值，控制FDR小于一定阈值可以降低差异表达$type的假阳性率。不同的项目可根据项目的特异情况选择合适的指标进行差异筛选。";

my $dir_relate= (split /\//,(dirname $od))[-1];#获得相对路径BMK_Result或者Web_Report
print "$od\n";
print "$dir_relate\n";
$density=abs_path($density);
my $density_dir=(split(/$dir_relate\//,$density))[1];  ##获得相对路径BMK_2_lncRNA/BMK_*_*_Expression
print "$density_dir\n";
$density_dir = "../$density_dir";

$deg=abs_path($deg);
my $deg_dir=(split(/$dir_relate\//,$deg))[1];	##获得相对路径BMK_2_lncRNA/BMK_*_DEG_Analysis
print "$deg_dir\n";

my @GROUP;my %hash;
my @group = glob "$deg/*_vs_*";
foreach my $G(@group){
	my $g = (split /\//,$G)[-1];
	push @GROUP,$g;
	if($g=~/BMK_\d+_(.*)/){
		$hash{$g}=$1;
	}
}


my %method=();my %pic=();my %picinfo=();
$method{miRNA}="TPM";
$method{lncRNA}="FPKM";
$method{gene}="FPKM";

my $template_dir= "template";
$pic{miRNA}="$template_dir/miRNA_TPM.png";
$pic{lncRNA}="$template_dir/FPKM.png";
$pic{gene}="$template_dir/FPKM.png";
if($config{normalization} eq "SRPBM"){
	$pic{circRNA}="$template_dir/circRNA_SRPBM.png";
	$method{circRNA}="SRPBM";
}else{
	$pic{circRNA}="$template_dir/circRNA_TPM.png";
	$method{circRNA}="TPM";
	$picinfo{circRNA}="公式中，R是指环状RNA的junction reads, L指reads长度，k指RNA个数";
}

$picinfo{miRNA}="公式中，readcount表示比对到某一miRNA的reads数目;Mapped Reads表示比对到所有miRNA上的reads数目。";
$picinfo{lncRNA}="公式中，cDNA Fragments表示比对到某一转录本上的片段数目，即双端Reads数目;Mapped Fragments (Millions)表示比对到转录本上的片段总数，以百万为单位;Transcript Length(kb)：转录本长度。";
$picinfo{gene}=$picinfo{lncRNA};

my ($pid,$tid)=(0,0);

my $report_time=&gaintime();
my $writer = XML::Writer->new(OUTPUT => 'self');
$writer->xmlDecl('UTF-8');
$writer->startTag('report');
$writer->emptyTag('report_version','value'=>$config{report_version});
my $report_name;
if($deg_flag==1){
	$report_name = "$type 表达量及差异分析";
}else{
	$report_name = "$type 表达量分析";
}
$writer->emptyTag('report_name','value'=>$report_name);
$writer->emptyTag('report_code','value'=>$config{report_code});
$writer->emptyTag('report_user','value'=>$config{report_user});
$writer->emptyTag('report_user_addr','value'=>$config{report_user_addr});
$writer->emptyTag('report_time','value'=>"XXXX/XX/XX;XXXX/XX/XX;XXXX/XX/XX;$report_time");
$writer->emptyTag('report_abstract','value'=>"");
###############################摘要
$writer->emptyTag('h1','name'=>"1 $type 表达量分析",'type'=>'type1','desc'=>"1 $type 表达量分析");
###
$writer->emptyTag('h2','name'=>"1.1 $type 定量",'type'=>'type1','desc'=>"1.1 $type 定量");
$writer->emptyTag('p','desc'=>"对各样本中$type 进行表达量的统计，并用$method{$type} 算法对表达量进行归一化处理。$method 归一化处理公式为：",'type'=>"type1");
$pid++;
$writer->emptyTag('pic','desc'=>"$picinfo{$type}",'name'=>"图$pid. $method{$type}标准化公式 ",'type'=>"type1",'path'=>"$pic{$type}");
###
$writer->emptyTag('h2','name'=>"1.2 样品表达量总体分布",'type'=>'type1','desc'=>"1.2 样品表达量总体分布");
$writer->emptyTag('p','desc'=>"$type 表达量总体分布图能反映样品中$type的整体表达模式，结果见下图：",'type'=>"type1");
$pid++;
$writer->emptyTag('pic','desc'=>"注：图中不同颜色的曲线代表不同的样品，横坐标表示对应样品$method{$type}的对数值，纵坐标表示概率密度。",'name'=>"图$pid. 各样品$method{$type}密度分布对比图",'type'=>"type1",'path'=>"$density_dir/PNG/all.fpkm_density.png");
$writer->emptyTag('p','desc'=>"从箱线图中不仅可以查看单个样品表达水平分布的离散程度，还可以直观的比较不同样品的整体表达水平。该项目各样品的$method{$type}分布箱线图如下：",'type'=>"type1");
$pid++;
$writer->emptyTag('pic','desc'=>"注：图中横坐标代表不同的样品，纵坐标表示样品表达量$method{$type}的对数值。该图从表达量的总体离散角度来衡量各样品表达水平。",'name'=>"图$pid. 各样品的$method{$type}箱线图",'type'=>"type1",'path'=>"$density_dir/PNG/all.fpkm_box.png");
###

my $hid=2;
if($deg_flag==1){
$writer->emptyTag('h2','name'=>"1.3 样品表达量相关性",'type'=>'type1','desc'=>"1.3 样品表达量相关性");
$writer->emptyTag('p','desc'=>"研究表明，RNA表达在不同的个体间存在生物学可变性（Biological Variability），不同的RNA之间表达的可变程度存在差异，而高通量测序技术、qPCR以及生物芯片等技术都不能消除这种可变性。为了寻找真正感兴趣的差异表达RNA，需要考虑和处理因生物学可变性造成的表达差异。目前最常用且最有效的方法是在实验设计中设立生物学重复（Biological Replicates）。重复条件限制越严格，重复样品数目越多，寻找到的差异表达RNA越可靠。对于设立生物学重复的项目，评估生物学重复的相关性对于分析转录组测序数据非常重要。生物学重复的相关性不仅可以检验生物学实验操作的可重复性；还可以评估差异表达RNA的可靠性和辅助异常样品的筛查。",'type'=>"type1");
$writer->emptyTag('p','desc'=>"相关系数(Correlation coefficient) 是用以反映变量之间相关关系密切程度的统计指标。皮尔森相关系数（Pearson correlation coefficient）也叫皮尔森积差相关系数（Pearson product-moment correlation coefficient），是用来反应两个变量相似程度的统计量。计算公式如下：",'type'=>"type1");
$pid++;
$writer->emptyTag('pic','desc'=>"分子是协方差，分母是两个变量标准差的乘积。要求X和Y的标准差都不能为0。当两个变量的线性关系增强时，相关系数趋于1或-1。正相关时趋于1，负相关时趋于-1。当两个变量独立时相关系统为0，但反之不成立。",'name'=>"图$pid. 皮尔森相关系数",'type'=>"type1",'path'=>"$template_dir/pearson.png");
$writer->emptyTag('p','desc'=>"样品间的相关性关系见下图",'type'=>"type1");
$pid++;
$writer->emptyTag('pic','desc'=>"注：颜色代表了相关系数的大小，蓝色越深表示相关性越大，红色越深表示相关性越小。",'name'=>"图$pid. 样品相关性关系图",'type'=>"type1",'path'=>"$density_dir/PNG/sample_corelation.png");

if(!defined $cloud){
	$writer->emptyTag('file','desc'=>"",'name'=>"$type表达量相关分析结果路径",'action'=>"xls",'path'=>"../$density_dir/PNG/",'type'=>"xls");
}

if(defined $deg && -d $deg){
	$writer->emptyTag('h1','name'=>"2 $type 差异表达分析",'type'=>'type1','desc'=>"2 $type 差异表达分析");
	$desc="表达具有时间和空间特异性，在两个不同条件下，表达水平存在显著差异的$type，称之为差异表达$type。差异分组使用\"A_vs_B\"的方式命名。根据两（组）样品之间表达水平的相对高低，差异表达$type可以划分为上调$type（Up-regulated $type）和下调$type（Down-regulated $type）。上调$type在样品（组）B中的表达水平高于样品（组）A中的表达水平；反之为下调$type。上调和下调是相对的，由所给A和B的顺序决定。";
	$desc=~s/gene/基因/g;
	$writer->emptyTag('p','desc'=>"$desc",'type'=>"type1");
	if(!defined $cloud){
		$writer->emptyTag('file','desc'=>"",'name'=>"$type差异分析结果路径",'action'=>"xls",'path'=>"../../$deg_dir/",'type'=>"xls");
	}

	$writer->emptyTag('h2','name'=>"2.1 差异表达筛选",'type'=>'type1','desc'=>"2.1 差异表达筛选");
	$writer->emptyTag('p','desc'=>"$demethod",'type'=>"type1");
	$writer->emptyTag('table','desc'=>"注：DEG_Set：差异表达$type集名称；All_DEG：差异表达$type数目；up-regulated：上调$type的数目；down-regulated：下调$type的数目。",'type'=>"part",'name'=>"差异表达$type数目统计表",'path'=>"../$deg_dir/DEG.stat.xls");

	$writer->emptyTag('p','desc'=>"通过火山图（Volcano Plot）可查看$type 在两个（组）样品中表达水平的差异，以及差异的统计学显著性。样品差异表达火山图见下图：",'type'=>"type1");
	&piclist("差异表达火山图","注：差异表达火山图中的每一个点表示一个$type, 横坐标表示某一个$type在两样品中表达量差异倍数的对数值；纵坐标表示$flag 的负对数值。横坐标绝对值越大，说明表达量在两样品间的表达量倍数差异越大；纵坐标值越大，表明差异表达越显著，筛选得到的差异表达$type越可靠。图中绿色的点代表下调差异表达$type, 红色的点代表上调差异表达$type, 黑色代表非差异表达$type。","$deg/*_vs_*/BMK_1_Statistics_Visualization/*Volcano.png","$dir_relate");

	$writer->emptyTag('p','desc'=>"通过MA图可以直观地查看$type的两个（组）样品的表达水平和差异倍数的整体分布。样品间差异表达MA图见下图:",'type'=>"type1");
	&piclist("差异表达MA图","注：差异表达MA图中每一个点代表一个$type。 横坐标为A值：log2($method{$type})，即两样品中表达量均值的对数值；纵坐标为M值：log2(FC)，即两样品间$type 表达量差异倍数的对数值，用于衡量表达量差异的大小。图中绿色的点代表显著下调的$type, 红色的点代表显著上调的$type, 黑色的点代表表达差异不显著的$type。","$deg/*/BMK_1_Statistics_Visualization/*MA.png","$dir_relate");
	$writer->emptyTag('p','desc'=>"对筛选出的差异表达$type 做层次聚类分析，将具有相同或相似表达行为的$type 进行聚类，差异表达$type 聚类结果如下图：",'type'=>"type1");
	&piclist("差异表达$type 聚类图","注：横坐标代表样品名称及样品的聚类结果，纵坐标代表的差异$type 及$type 的聚类结果。图中不同的列代表不同的样品，不同的行代表不同的$type。颜色代表了$type在样品中的表达量水平log10（$type+0.000001）。","$deg/BMK*/BMK_1_Statistics_Visualization/*heatmap.png","$dir_relate");

	if(-e "$deg/BMK_1_All_DEG/Veen.png"){
		$writer->emptyTag('p','desc'=>"将每组差异$type 进行维恩图绘制，见下图。图中展示了各比较组特有的差异$type 的个数，以及比较组间的共有的差异$type 个数。",'type'=>"type1");
		$pid++;
		$writer->emptyTag('pic','desc'=>"注：每个圆圈代表一组差异分析组合，圆圈内的数字代表每个组合的差异$type 个数。",'name'=>"图$pid. 差异表达$type 维恩图",'type'=>"type1",'path'=>"../$deg_dir/BMK_1_All_DEG/Veen.png");
		if(!defined $cloud){
			$writer->emptyTag('file','desc'=>"",'name'=>"Venn图结果路径",'action'=>"xls",'path'=>"../../$deg_dir/BMK_1_All_DEG",'type'=>"xls");
		}
	}

	my $info;
	if($type eq "lncRNA"){
		$info="lncRNA顺式靶基因";
		&anno($writer,$info,"Cis");
		$info="lncRNA反式靶基因";
		$hid++;
		&anno($writer,$info,"Trans")	if(-e "$deg/DEG_Trans_anno.stat.xls");
	}else{
		$info.="基因"                   if($type eq "gene");
		$info.="circRNA来源基因"        if($type eq "circRNA");
		$info.="miRNA靶基因"            if($type eq "miRNA");
		&anno($writer,$info,$type);
	}
}
$writer->startTag('ref_list',desc=>"参考文献",type=>"type1",name=>"参考文献");
&reference ($writer,[
	["Robinson M D, McCarthy D J, Smyth G K. edgeR: a Bioconductor package for differential expression analysis of digital gene expression data[J]. Bioinformatics, 2010, 26(1): 139-140.","https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2796818/pdf/btp616.pdf","1"],
	["Anders S, Huber W. Differential expression analysis for sequence count data[J]. Genome Biology, 2010, 11(10):R106.","https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3218662/","2"],
	["Ning Leng and Christina Kendziorski (2014). EBSeq: An R package for gene and isoform differential expression analysis of RNA-seq data. ","https://www.biostat.wisc.edu/~kendzior/EBSEQ/","3"],
	["Yu G, Wang L G, Han Y, et al. clusterProfiler: an R Package for Comparing Biological Themes Among Gene Clusters[J]. Omics-a Journal of Integrative Biology, 2012, 16(5):284-287.","https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3339379/","4"],
	["Franceschini A1, Szklarczyk D, Frankild S, et al. STRING v9.1: protein-protein interaction networks, with increased coverage and integration. [Nucleic Acids Research Italic] 2013 Jan;41(Database issue):D808-15.","https://academic.oup.com/nar/article/41/D1/D808/1057425","5"],
	["Ge T, Boris L. TFBSTools: an R/bioconductor package for transcription factor binding site analysis:[J]. Bioinformatics, 2016, 32(10):1555-1556.","https://academic.oup.com/bioinformatics/article/32/10/1555/1743236","6"],
	["Khan A, Oriol Fornés, Stigliani A, et al. JASPAR 2018: update of the open-access database of transcription factor binding profiles and its web framework[J]. Nucleic Acids Research, 2017, 77(21):e43.","https://academic.oup.com/nar/article/46/D1/D1284/4637584","7"],
	["Nicolle R, Radvanyi F, Elati M. COREGNET: reconstruction and integrated analysis of co-regulatory networks[J]. Bioinformatics, 2015:btv305.","https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4565029/","8"],
	["Shen S., Park JW., Lu ZX., Lin L., Henry MD., Wu YN., Zhou Q., Xing Y. (2014) rMATS: Robust and Flexible Detection of Differential Alternative Splicing from Replicate RNA-Seq Data. PNAS, 111(51):E5593-601. doi: 10.1073/pnas.1419161111","https://www.pnas.org/content/111/51/E5593","9"],
	["Subramanian A, Tamayo P, Mootha VK, Mukherjee S, Ebert BL, et al. (2005) Gene set enrichment analysis: a knowledge-based approach for interpreting genome-wide expression profiles. Proc Natl Acad Sci U S A 102: 15545–15550.","https://www.ncbi.nlm.nih.gov/pmc/articles/PMC1239896/","10"],
]);
$writer->endTag('ref_list');

}#no deg end

$writer->endTag('report');
open OUT,">:utf8", "$output";
my $xmlstr=&decorate($writer->to_string);
$xmlstr = Encode::decode("utf-8", $xmlstr);
print OUT $xmlstr;
close(OUT);
$writer->end();
######################################sub function############################
sub anno{
	my ($writer,$info,$target_type)=@_;	
	my($stat,$path);
	$stat="DEG_${target_type}_anno.stat.xls"	if($target_type eq "Cis"||$target_type eq "Trans");
	$stat||="DEG_anno.stat.xls";
	$path="BMK_2_${target_type}_Anno_enrichment"	if($target_type eq "Cis");
	$path="BMK_3_${target_type}_Anno_enrichment"	if($target_type eq "Trans");
	$path||="BMK_2_Anno_enrichment";

	$writer->emptyTag('h2','name'=>"2.$hid 差异表达$info功能注释和富集分析",'type'=>'type1','desc'=>"2.$hid 差异表达$info功能注释和富集分析");
	$writer->emptyTag('p','desc'=>"对差异表达$info进行功能注释，各差异表达$info集注释到的基因数量统计见下表：",'type'=>"type1");	
	$writer->emptyTag('table','desc'=>"注：DEG Set：差异表达$info集名称;Annotated：注释到的差异表达$info数目;第三列到最后一列表示各功能数据库注释到的差异表达$info数目。",'type'=>"part",'name'=>"注释的差异表达$info数量统计表",'path'=>"../$deg_dir/$stat");
	####
	$writer->emptyTag('h3','name'=>"2.$hid.1 差异表达${info}GO分类",'type'=>'type1','desc'=>"2.$hid.1 差异表达${info}GO分类");
	$writer->emptyTag('p','desc'=>"GO数据库是GO组织（Gene Ontology Consortium）于2000年构建的一个结构化的标准生物学注释系统，旨在建立基因及其产物知识的标准词汇体系，适用于各个物种。GO注释系统是一个有向无环图，包含三个主要分支，即：生物学过程（Biological Process）、分子功能（Molecular Function）和细胞组分（Cellular Component）。",'type'=>"type1");
	$writer->emptyTag('p','desc'=>"样品间差异表达${info}GO分类统计结果见下图：");
	&piclist("差异表达${info}GO注释分类统计图","注：横坐标为GO分类，纵坐标左边为基因数目所占百分比，右边为基因数目。此图展示的是在差异表达$info背景和全部基因背景下GO各二级功能的基因富集情况，体现两个背景下各二级功能的地位，具有明显比例差异的二级功能说明差异表达$info与全部基因的富集趋势不同，可以重点分析此功能是否与差异相关。","$deg/*_vs_*/$path/BMK_1_Annotation/*png","$dir_relate");

	if(!defined $cloud){
		foreach my $gg(@GROUP){
			$writer->emptyTag('file','desc'=>"",'name'=>"$hash{$gg}：GO分类统计结果路径",'action'=>"xls",'path'=>"../../$deg_dir/$gg/$path/BMK_1_Annotation/",'type'=>"xls");
		}
	}
	####GO富集
	$writer->emptyTag('h3','name'=>"2.$hid.2 差异表达${info}GO富集分析",'type'=>'type1','desc'=>"2.$hid.2 差异表达${info}GO富集分析");
	$writer->emptyTag('p','desc'=>"采用R包clusterProfiler<a href=\"#ref4\">[4]</a>对$info分别进行生物学过程，分子功能和细胞组分的富集分析。富集分析采用超几何检验方法来寻找与整个基因组背景相比显著富集的GO条目。",'type'=>"type1");
	&piclist("差异表达${info}GO富集图(BP分支)","注：横坐标为GeneRatio即注释在该条目中的感兴趣基因占所有差异$info数的比例, 纵坐标每一个BP条目。点的大小代表该通路中注释的差异表达$info数，点的颜色代表超几何检验的校正后的p值。","$deg/*_vs_*/$path/BMK_2_GO_enrich/*Biological_Process_enrich_dotplot.png","$dir_relate");
	&piclist("差异表达${info}GO富集图(CC分支)","注：横坐标为GeneRatio即注释在该条目中的感兴趣基因占所有差异$info数的比例, 纵坐标每一个CC条目。点的大小代表该通路中注释的差异表达$info数，点的颜色代表超几何检验的校正后的p值。","$deg/*_vs_*/$path/BMK_2_GO_enrich/*Cellular_Component_enrich_dotplot.png","$dir_relate");
	&piclist("差异表达${info}GO富集图(MF分支)","注：横坐标为GeneRatio即注释在该条目中的感兴趣基因占所有差异$info数的比例, 纵坐标每一个MF条目。点的大小代表该通路中注释的差异表达$info数，点的颜色代表超几何检验的校正后的p值。","$deg/*_vs_*/$path/BMK_2_GO_enrich/*Molecular_Function_enrich_dotplot.png","$dir_relate");

	if(!defined $cloud){
		foreach my $gg(@GROUP){
			$writer->emptyTag('file','desc'=>"",'name'=>"$hash{$gg}：GO富集分析结果路径",'action'=>"xls",'path'=>"../../$deg_dir/$gg/$path/BMK_2_GO_enrich/",'type'=>"xls");
		}
	}
	####KEGG富集图
	$writer->emptyTag('h3','name'=>"2.$hid.3 差异表达${info}KEGG富集分析",'type'=>'type1','desc'=>"2.$hid.3 差异表达${info}KEGG富集分析");
	$writer->emptyTag('p','desc'=>"在生物体内，不同的基因产物相互协调来行使生物学功能，对差异表达基因的通路（Pathway）注释分析有助于进一步解读基因的功能。KEGG（Kyoto Encyclopedia of Genes and Genomes）数据库有助于研究者把基因及表达信息作为一个整体网络进行研究。作为有关Pathway的主要公共数据库(Kanehisa，2008），KEGG提供的整合代谢途径 (pathway)查询，包括碳水化合物、核苷、氨基酸等的代谢及有机物的生物降解，不仅提供了所有可能的代谢途径，而且对催化各步反应的酶进行了全面的注解，包含有氨基酸序列、PDB库的链接等等，是进行生物体内代谢分析、代谢网络研究的强有力工具。",'type'=>"type1");
	$writer->emptyTag('p','desc'=>"采用R包clusterProfiler对$info分别进行KEGG通路富集分析。富集分析采用超几何检验方法来寻找与整个基因组背景相比显著富集的KEGG通路。",'type'=>"type1");

	$desc="注：横坐标代表差异表达$info注释在通路中的基因数，纵坐标代表通路，柱的颜色代表校正后的p值。";
	my $name="差异表达${info}KEGG富集条形图";
	my $pics="$deg/*_vs_*/$path/BMK_3_KEGG_enrich/*KEGG_pathway_enrich_barplot.png";
	$pics="$deg/*_vs_*/$path/BMK_3_KEGG_enrich/*.Phase.png"	if($type eq "gene");
	$desc="注：图中每一个图形表示一个KEGG通路，通路名称见右侧图例。横坐标为富集因子（Enrichment Factor），表示差异$info中注释到该通路的基因比例与所有基因中注释到该通路的基因比例的比值。富集因子越大，表示差异表达$info在该通路中的富集水平越显著。纵坐标为-log10(Q-value)，其中Q-value为多重假设检验校正之后的P-value。因此，纵坐标越大，表示差异表达$info在该通路中的富集显著性越可靠。"	if($type eq "gene");
	$name="差异表达${info}KEGG通路富集散点图"        if($type eq "gene");
	&piclist("$name","$desc","$pics","$dir_relate");
	$writer->startTag('file_list','name'=>"",'desc'=>"",'type'=>"type1");
	###########KEGG Enrichment html
	my @kegg_enrich=glob("$deg/*/$path/BMK_3_KEGG_enrich/*KEGG_pathway_enrich.list.xls");
	my %second_links=();
	my $dir_data="$dir_relate/";
	foreach my $list (@kegg_enrich) {
		my $key_name=basename $list;
		my $key_dir=dirname $list;
		my $vs=(split(/_KEGG_/,$key_name))[0];
		$key_name="$vs.Cis_target"	if($target_type eq "Cis");
		$key_name="$vs.Trans_target"	if($target_type eq "Trans");
		$key_name="$vs.Source"		if($target_type eq "circRNA");
		$key_name="$vs.Target"		if($target_type eq "miRNA");
		$key_name="$vs"			if($target_type eq "gene");
		$/="\n";
		open(IN,$list)||die $!;
		while(<IN>){
			chomp;
			my @tmp=split(/\t/,$_);	###ko04512 name 92/4161 101/7234 1.58 6.2e-14    1.3e-11
			my $mid_path   =abs_path("$key_dir/BMK_1_Keggmap/$tmp[0].html");
			$mid_path      =(split(/$dir_data/,$mid_path))[1];
			$second_links{KEGG}{$key_name}{$tmp[0]}="../../$mid_path";
		}
		close(IN);
		&table_html($list,"$od/$type/$key_name.html","$vs差异表达$info的KEGG富集结果",",1,",\%{$second_links{KEGG}},"src","注：ID: KEGG通路ID；Description: KEGG通路名称；GeneRatio: 感兴趣的基因集中该通路的基因比例 ；BgRatio: 背景基因集中该通路的基因比例 ；enrich_factor: 富集因子；pvalue: 富集显著性p值；qvalue: 富集显著性q值；geneID: 通路中感兴趣的基因列表。");
		if(!defined $cloud){
			$writer->emptyTag('file','desc'=>"",'name'=>"$vs：差异表达基因的KEGG富集结果.html",'action'=>"xls",'path'=>"$key_name.html",'type'=>"xls");
		}else{
			$writer->emptyTag('file','desc'=>"",'name'=>"$vs：差异表达基因的KEGG富集结果.html",'action'=>"xls",'path'=>"../HTML/$type/$key_name.html",'type'=>"xls");
		}
	}
	$writer->endTag('file_list');
	$writer->emptyTag('p','desc'=>"注：上述网页中包含每个差异分组中差异表达$info的KEGG富集的详细情况(包含注释上的所有通路)。",'type'=>"type1")	if(@kegg_enrich>0);

	if(!defined $cloud){
		foreach my $gg(@GROUP){
			$writer->emptyTag('file','desc'=>"",'name'=>"$hash{$gg}：KEGG富集分析结果路径",'action'=>"xls",'path'=>"../../$deg_dir/$gg/$path/BMK_3_KEGG_enrich/",'type'=>"xls");
		}
	}
	#############################

	if($type eq "gene"){
		my $h3=4;
		$writer->emptyTag('h3','name'=>"2.$hid.$h3 差异表达基因蛋白互作网络",'type'=>'type1','desc'=>"2.$hid.$h3 差异表达基因蛋白互作网络");
		$writer->emptyTag('p','desc'=>"STRING<a href=\"#ref5\">[5]</a>是收录多个物种预测的和实验验证的蛋白质-蛋白质互作的数据库，包括直接的物理互作和间接的功能相关。结合差异表达分析结果和数据库收录的互作关系对，构建差异表达基因互作网络。",'type'=>"type1");
		$writer->emptyTag('p','desc'=>"对于数据库中包含的物种，可直接从数据库中提取出目标基因集的互作关系对构建互作网络；对于数据库中未收录信息的物种，使用BLAST软件，将目的基因与数据库中的蛋白质进行序列比对，寻找同源蛋白，根据同源蛋白的互作关系对构建互作网络。构建完成的蛋白质互作网络可导入Cytoscape软件进行可视化。",'type'=>"type1");
		$writer->emptyTag('p','desc'=>"Cytoscape可视化的差异表达基因蛋白质互作网络示意图如下：",'type'=>"type1");
		$pid++;
		$writer->emptyTag('pic','desc'=>"注：图中的节点为蛋白质，边为互作关系。互作网络中节点(node)的大小与此节点的度(degree)成正比，即与此节点相连的边越多，它的度越大，节点也就越大。节点的颜色与此节点的聚集系数(clustering coefficient)相关，颜色梯度由绿到红对应聚集系数的值由低到高；聚集系数表示此节点的邻接点之间的连通性好坏，聚集系数值越高表示此节点的邻接点之间的连通性越好。边(edge)的宽度表示此边连接的两个节点间的互相作用的关系强弱，互相作用的关系越强，边越宽。没有的组合代表没有互作关系。",'name'=>"图$pid. 差异表达基因蛋白质互作网络图",'type'=>"type1",'path'=>"$template_dir/ppi.png");
		$writer->emptyTag('p','desc'=>"下述为每个差异分组中差异基因的蛋白质互作关系：",'type'=>"type1");
		&filelist("","$deg/BMK_2_DEG_PPI/*.sif","$deg_dir");
		if(!defined $cloud){
			$writer->emptyTag('file','desc'=>"",'name'=>"差异表达基因蛋白互作分析结果路径",'action'=>"xls",'path'=>"../../$deg_dir/BMK_2_DEG_PPI/",'type'=>"xls");
		}
		my @cosmic=glob("$deg/*_vs_*/BMK_1_Statistics_Visualization/*.DEG_cosmic.xls");
		my @tf=glob("$deg/*_vs_*/BMK_1_Statistics_Visualization/*.DEG_TF.xls");
		if(@cosmic>0){	
			$h3++;
			$writer->emptyTag('h3','name'=>"2.$hid.$h3 癌症基因功能注释",'type'=>'type1','desc'=>"2.$hid.$h3 癌症基因功能注释");
			$writer->emptyTag('p','desc'=>"原癌基因（Proto-oncogene）是参与细胞生长、分裂和分化的正常基因，当其发生突变后（如基因序列被改变）就会变成致癌基因（Oncogene）。通常在肿瘤或恶性细胞系中某些特异性癌基因会上调表达，通过了解癌基因在不同实验组的表达情况有助于深入认识疾病的发病机理。Cosmic(https://cancer.sanger.ac.uk/cosmic)是英国Sanger实验室开发并维护的癌基因及相关注释数据库，有较高的权威性和可信度，通过Cosmic数据库，可对差异表达基因中的癌基因部分进行注释。",'type'=>"type1");
			$writer->emptyTag('p','desc'=>"Oncogenes分析结果",'type'=>"type1");
			&filelist("注：ID，Ensembl基因ID；Gene_Symbol，基因通用名称；log2FC，样品间差异倍数变化；Regulated，差异上下调状态；Description，基因描述；Tumor Type(Somatic)，体细胞癌症类型；Tumor Type(Germline)，生殖细胞系癌症类型。","$deg/*_vs_*/BMK_1_Statistics_Visualization/*.DEG_cosmic.xls","$deg_dir");
		}
		##########转录因子分析
		$hid++;
		$writer->emptyTag('h2','name'=>"2.$hid 转录因子分析",'type'=>'type1','desc'=>"2.$hid 转录因子分析");
		if(@tf>0){
			$writer->emptyTag('h3','name'=>"2.$hid.1 转录因子注释",'type'=>'type1','desc'=>"2.$hid.1 转录因子注释");
			$writer->emptyTag('p','desc'=>"转录水平调控是基因表达调控的重要环节，其中转录因子（Transcriptionfactor，TF）通过结合基因上游特异性核苷酸序列实现对该基因的转录调控，许多生物学功能都通过调节特异性转录因子实现对下游功能基因的激活或抑制，因此有必要注释不同分组间差异表达基因的转录组因子，使用动物转录因子数据库AnimalTFDB3.0对差异表达基因中的转录因子进行鉴定。",'type'=>"type1");
			$writer->emptyTag('p','desc'=>"Transcription_factor分析结果",'type'=>"type1");
			&filelist("注:ID，Ensembl基因ID；Gene_Symbol，基因通用名称；log2FC，样品间差异倍数变化；Regulated，差异上下调状态；Family，转录因子所属的家族。","$deg/*_vs_*/BMK_1_Statistics_Visualization/*.DEG_TF.xls","$deg_dir");
		}
		
		###TFBS analysis
		my @tfbs_xls = glob "$deg/BMK_3_TFBS_Analysis/*Genes_TFBS_predictRes.xls";
		if(@tfbs_xls>0){
			$writer->emptyTag('h3','name'=>"2.$hid.2 转录因子结合位点预测",'type'=>'type1','desc'=>"2.$hid.2 转录因子结合位点预测");
			$writer->emptyTag('p','desc'=>"转录因子结合位点（Transcription factor binding site，TFBS）是与转录因子结合的DNA片段，长度通常在 5~20 bp范围内，一个转录因子往往同时调控若干个基因，而它在不同基因上的结合位点具有一定的保守性，又不完全相同。我们用R包TFBStools<a href=\"#ref6\">[6]</a>对差异基因的启动子区域（定义基因上游１kb 左右为潜在的启动子区）上的 TFBS 进行了预测，参考的转录因子 motif 数据库是 JASPAR 数据库<a href=\"#ref7\">[7]</a>（http://jaspar.genereg.net/）。预测结果如下表：",'type'=>"type1");
			$writer->emptyTag('table','desc'=>"注：Model_id：转录因子结合位点模体id；seqname：基因名称；start：开始位置；end：结束位置；score：评分，评分越高，表示该转录因子与输入序列结合的可能性越大；strand：链方向；frame：.；TF：转录因子id；class：转录因子注释；sequence：TFBS序列；Pvalue：P值。",'type'=>"part",'name'=>"转录因子结合位点预测结果",'path'=>"$template_dir/tfbs.xls");
			$writer->emptyTag('p','desc'=>"TFBS序列特征示例图如下：",'type'=>"type1");
			$pid++;
			$writer->emptyTag('pic','desc'=>"注：横坐标为 motif 中碱基的相对位置，纵坐标为该位置碱基的序列保守性，而碱基信号的高度代表该碱基在该位置上的相对频率。",'name'=>"图$pid. TFBS序列特征图",'type'=>"type1",'path'=>"$template_dir/TFBS_seqlogo.png");
		#	&piclist("TFBS序列特征图","注：横坐标为 motif 中碱基的相对位置，纵坐标为该位置碱基的序列保守性，而碱基信号的高度代表该碱基在该位置上的相对频率。","$deg/BMK_4_TF_Analysis/seqLogo/*png","$dir_relate");
			if(!defined $cloud){
			 	$writer->emptyTag('file','desc'=>"",'name'=>"TFBS序列特征图路径",'action'=>"pdf",'path'=>"../../$deg_dir/BMK_3_TFBS_Analysis/seqLogo/",'type'=>"pdf");
			#	&filelist("TFBS序列特征图","$deg/BMK_3_TFBS_Analysis/seqLogo/*pdf","$deg_dir");
			}
		}
		###TF_activity analysis
		my @tf_activity = glob "$deg/BMK_4_TF_activity/*influence.xls";
		if(@tf_activity>0){
			$writer->emptyTag('h3','name'=>"2.$hid.3 转录因子活性分析",'type'=>'type1','desc'=>"2.$hid.3 转录因子活性分析");
			$writer->emptyTag('p','desc'=>"转录因子活性是对转录因子调控作用或者转录影响力的一种衡量标准。由于基因的表达模式受 TFs 的调控，因此我们通过对 TFs 活性的评估有助于我们理解受其调控的基因的功能。此部分分析是基于R包 CoRegNet <a href=\"#ref8\">[8]</a>去分析的。CoRegNet 包实现了评估 TFs 在给定样品中的活性。其原理是通过输入的基因表达矩阵，根据 hLICORN 算法（CoRegNet包自带的算法）推测基因与转录因子之间的靶向关系从而得到一个大规模共调控网络，同时评估转录因子在各个样本中的转录活性和得到了共调控的 TFs 对。其结果包括：",'type'=>"type1");
			$writer->emptyTag('table','desc'=>"注：协作转录因子关系表：Reg1：TF1；Reg2：TF2；Support：活性评分；NA：同nGRN；nGRN：GRN表示基因调控网络；在h-Licorn算法中，对于每一个基因（无法作为TF靶基因的基因），会根据转录组表达数据来鉴定出一组系列候选基因调控网络GRN1，GRN2，···，GRNn。 对于给定的基因g，GRN由一组共激活TFs（A）和一组共抑制TFs（I）组成，GRN =（A，I，g），其中A和I是TF组，但两者都不能为空且无交集。 nGRN表示调控网络中TFs的数目（A + I）。如果未设定nGRN的值，则选择最佳GRN中TF的数目；fisherTest：fisher精确检验P值；adjustedPvalue：校正后的P值。",'type'=>"part",'name'=>"协作转录因子关系表",'path'=>"$template_dir/tfs_cornet.xls");
			$writer->emptyTag('p','desc'=>"转录因子共调控网络示例图如下：",'type'=>"type1");
			$pid++;
			$writer->emptyTag('pic','desc'=>"注：协作TFs的调控网络图：图中的节点为转录因子 TFs，边为存在协作关系。边(edge)的宽度表示此边连接的两个节点间的协作作用的关系强弱，协作作用的关系越强，边越宽。没有的组合代表没有协作关系。边的粗细同 nGRN 成正比。",'name'=>"图$pid. 转录因子共调控网络图",'type'=>"type1",'path'=>"$template_dir/TFs_network.png");
                #       &piclist("网络图","注：协作TFs的调控网络图，","$deg/BMK_4_TF_activity/TFs_network.png","$dir_relate");
                #
			$writer->emptyTag('table','desc'=>"注：转录因子活性分析表：第一列表示转录因子(TF)，第二到最后一列依次表示TF在不同的样品中的活性评分；评分的绝对值越高表示 TF 的转录活性越高；负值表示负向调控，正值表示正向调控。",'type'=>"part",'name'=>"转录因子活性分析",'path'=>"$template_dir/tfs_influence.xls");
			$writer->emptyTag('p','desc'=>"转录因子活性聚类热图示例图如下：",'type'=>"type1");
			$pid++;
			$writer->emptyTag('pic','desc'=>"转录因子活性聚类热图：注：横坐标代表样品名称及样品的聚类结果，纵坐标代表的TF及TF的聚类结果。图中不同的列代表不同的样品，不同的行代表不同的TF。颜色代表了TF在样品中的活性评分，红色表示正向调控基因的 TF 的活性，蓝色表示负向调控基因的 TF 的活性；颜色越深 TF 活性越高。",'name'=>"图$pid. 转录因子活性聚类热图",'type'=>"type1",'path'=>"$template_dir/TFs_influences_heatmap.png");
                #       &piclist("聚类热图","注：横坐标代表转录因子，纵坐标为不同样本。","$deg/BMK_4_TF_activity/TFs_influences_heatmap.png","$dir_relate");

			$writer->emptyTag('table','desc'=>"注：转录因子与基因互作关系表：Target：基因ID；coact：激活基因的TF；corep：抑制基因的TF；Coef.Acts：激活基因的TF的活性评分；Coef.Reps：抑制基因的TF的活性评分；Coef.coActs：协作调控TFs的活性评分；Coef.coReps：互遏调控TFs的活性评分；R2：确定系数，区间通常在（0,1）之间，通过数据的变化来表征一个拟合（即预测的正确性）的好坏。；RMSE：标准误差，用来衡量观测值同真值之间的偏差。",'type'=>"part",'name'=>"转录因子与基因互作关系表",'path'=>"$template_dir/tfs_activity_grn.xls");
		}

		###rMATs diff AS
		$hid++;
		$writer->emptyTag('h1','name'=>"3 差异可变剪切分析",'type'=>'type1','desc'=>"3 差异可变剪切分析");
		$writer->emptyTag('p','desc'=>"差异可变剪切分析是通过 rMATS 软件<a href=\"#ref9\">[9]</a>来实现的。其通过rMATS统计模型对不同样本（不同差异分组内）进行可变剪切事件的表达定量，将唯一比对到转录本（the exon inclusion isoform 或 the exon skipping isoform）的 reads 数定义为剪切位点的 Inclusion Level；然后以 likelihood-ratio test 计算 P value 来表示两组样品在 IncLevel（Inclusion Level）水平上的差异，并用 Benjamini Hochberg 算法对 p value 进行校正得到 FDR 值。在本分析中，默认使用 rMATS 的筛选标准：|Δψ| > c (c=0.0001)；具体而言，rMAT 使用似然比检验来计算 p 值，即两个样本组之间的平均 ψ 值的差异超过给定阈值 c 。rMATS 软件可识别的可变剪切事件有以下5种：外显子跳跃（SE），5′端外显子可变剪切（A5SS），3'端外显子可变剪切（A3SS），外显子选择性跳跃（MXE）和内含子滞留（RI），如下图：",'type'=>"type1");
		$pid++;
		$writer->emptyTag('pic','desc'=>"",'name'=>"图$pid. 差异可变剪接类型",'type'=>"type1",'path'=>"$template_dir/splicing.png");
		my @diffas=glob("$deg/*_vs_*");
		if(@diffas>0){
			$writer->emptyTag('p','desc'=>"rMATS软件分析结果:",'type'=>"type1");
			foreach my $as (@diffas) {
				my $re_dir=(split /\//,$as)[-1];
				my $name=basename $as;
				my $disc="$name"." 的差异可变剪切结果文件路径";
				if(!defined $cloud){
					$writer->emptyTag('file','desc'=>"",'name'=>"$disc",'action'=>"xls",'path'=>"../../$deg_dir/$re_dir/BMK_3_diff_AS_analysis/",'type'=>"xls");
				}else{
					&filelist("注：$name的差异可变剪切结果","$deg_dir/$re_dir/BMK_3_diff_AS_analysis/*.xls","$dir_relate");
				}
			}
			$writer->emptyTag('table','desc'=>"注：GeneID：基因的ID；geneSymbol：基因的symbol；chr：染色体编号；Strand：正负链信息；exonStart_0base：外显子起始位点（从0开始）；exonEnd：外显子终止位点；upstreamES：上游外显子起始位点；upstreamEE：上游外显子终止位点；downstreamES：下游外显子起始位点；downstreamEE：下游外显子终止位点（其他可变剪切文件的这几列略微不同）；ID：事件编号；IJC_SAMPLE_1：SAMPLE_1的inclusion junction counts数，样本的不同重复之间用逗号分隔；SJC_SAMPLE_1：SAMPLE_1的skipping junction counts数，样本的不同重复之间用逗号分隔；IJC_SAMPLE_2：SAMPLE_2的inclusion junction counts数，样本的不同重复之间用逗号分隔；SJC_SAMPLE_2：SAMPLE_2的skipping junction counts数，样本的不同重复之间用逗号分隔；IncFormLen：inclusion form的有效长度值；SkipFormLen：skipping form的有效长度值；P-Value：两个样本组之间可变剪切事件差异的显著性；FDR：FDR值；IncLevel1：差异分组SAMPLE_1的不同样品的Inclusion Level值（不同重复之间以逗号分隔）；IncLevel2：差异分组SAMPLE_2的不同样品的Inclusion Level值（不同重复之间以逗号分隔）；IncLevelDifference：average(IncLevel1) – average(IncLevel2)。",'type'=>"full",'name'=>"示例：差异可变剪切事件分析结果（以SE剪切事件为例）",'path'=>"$template_dir/diff_SE_AS.xls");
			$writer->emptyTag('p','desc'=>"差异可变剪切事件统计结果:",'type'=>"type1");
			$writer->emptyTag('table','desc'=>"注：DEG Set：差异表达基因集名称;第二列到最后一列表示发生各类可变剪切事件的差异基因数目。A3SS：3'端外显子可变剪切；A5SS：5′端外显子可变剪切；MXE：外显子选择性跳跃；RI：内含子滞留；SE：外显子跳跃。",'type'=>"full",'name'=>"差异可变剪切事件统计表",'path'=>"../$deg_dir/Diff.AS.stat.xls");
		}
		
	        ###GSEA
        	$hid++;
		$writer->emptyTag('h1','name'=>"4 GSEA分析",'type'=>'type1','desc'=>"4 GSEA分析");
		$writer->emptyTag('p','desc'=>"基因集富集分析(GSEA: Gene Set Enrichment Analysis)<a href=\"#ref10\">[10]</a>，可以在没有先验经验存在的情况下根据所有基因表达情况对所有基因进行富集分析。一般的差异分析通常只集中关注于一些显著的上调或下调基因，而这会遗漏部分差异表达不显著却有重要生物学意义的基因。而GSEA不会设置差异阈值，能够检测出微弱但是一致的趋势。本项目中的GSEA分析采用KEGG通路以及GO的BP、CC、MF分支的基因集作为感兴趣的基因集合，以每个差异分组的log2FC作为背景基因集的打分来分析感兴趣基因集合的富集情况，最后可控制pvalue<0.001，FDR<0.05 作为显著富集的基因集合。",'type'=>"type1");
		$writer->emptyTag('p','desc'=>"在这里,我们根据GSEA的分析结果，选择富集的前5个GO节点/pathway做富集图，如下：",'type'=>"type1");
		my @files=glob("$deg/*_vs_*/*Anno_enrichment/BMK_4_GSEA/BMK_1_Plot/*runningScore.png");
		if(@files>0){
			&piclist("GSEA runningScore图","注：横坐标代表排序后的基因集的位置信息，纵坐标为动态的富集打分。图形顶部的竖线代表感兴趣基因集合中的基因。绿色的曲线代表每个位置上基因集合的富集打分。","$deg/*_vs_*/*Anno_enrichment/BMK_4_GSEA/BMK_1_Plot/*runningScore.png","$dir_relate");
			&piclist("GSEA preranked图","注：横坐标代表排序后的基因集的位置信息，纵坐标代表打分信息。每一条竖线代表感兴趣基因集合中的基因，竖线的高低代表打分的高低。","$deg/*_vs_*/*Anno_enrichment/BMK_4_GSEA/BMK_1_Plot/*preranked.png","$dir_relate");
		}
		if(!defined $cloud){
			foreach my $gg(@GROUP){
				$writer->emptyTag('file','desc'=>"",'name'=>"$hash{$gg}：GSEA分析结果路径",'action'=>"xls",'path'=>"../../$deg_dir/$gg/$path/BMK_4_GSEA/",'type'=>"xls");
			}
		}
	}
	return $writer;
}
################################################################################################
#		                        sub function
################################################################################################
sub decorate{
	my $xmlstr=shift;
	$xmlstr=~s/(<[^>]*)\>/$1\>\n/mgo;
	return $xmlstr;
}


sub reference  {
    my ($writer,$list)=@_;
    my ($data,$value,$unit,$item);
    
    foreach $data (@$list)    {		
	$writer->emptyTag('ref','name'=>$$data[0],'link'=>$$data[1],'id'=>$$data[2]);
    }    
}


sub piclist{
	my ($name,$desc,$pics,$path)=@_;
	$pid++;
	$writer->startTag('pic_list','name'=>"图$pid. $name",'desc'=>"$desc",'type'=>"type1");
	my @images=glob("$pics");
	foreach my $s(@images){
		my $base=basename $s;
		my $dir=dirname $s;
		my $tmp=(split(/$path\//,$dir))[1];
        	$writer->emptyTag('pic','desc'=>"",'name'=>"$base",'type'=>"type1",'path'=>"../$tmp/$base");
	}
	$writer->endTag('pic_list');
}

sub filelist{
	my ($desc,$pics,$path)=@_;
	$writer->startTag('file_list','name'=>"",'desc'=>"$desc",'type'=>"type1");
	my @images=glob("$pics");
	foreach my $s(@images){
		my $base=basename $s;
		my $dir=dirname $s;
		my $tmp=(split(/$path\//,$dir))[1];
		my $new_path = "$path/$tmp";
        	$writer->emptyTag('file','desc'=>"",'name'=>"$base",'action'=>"xls",'path'=>"$relate_cloud/$new_path/$base",'type'=>"xls");
	}
	$writer->endTag('file_list');
}

sub readcfg{
	my %config=();
	open(CFG,$cfg)||die $!;
	while(<CFG>){
		chomp;next if($_=~/^#|^\s+|^$/);
		my @tmp=split(/\s+/,$_);
		$config{$tmp[0]}=$tmp[1];				
	}
	close(CFG);
	my @para=("fold","FDR","PValue","Method_RE","Method_NR");
	foreach my $pa(@para){
		$config{"$type.$pa"}=$config{$pa}	if(exists $config{$pa} && !exists $config{"$type.$pa"});
	}
	return %config;
}



sub gaintime{
	my $timestamp=time(); 
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($timestamp); 
	my $y = $year + 1900; 
	my $m = $mon + 1; 
	$timestamp=sprintf("%4d-%02d-%02d",$y,$m,$mday);
	return $timestamp
}
sub table_html{
        my ($input,$outHtml,$title,$linkColNum,$linkHash,$srcPath,$text)=@_;
        my @inputs=();
        $/="\n";
        my $i=0;
        open (IN,$input)||die $!;
        while(<IN>){
                chomp;
                next if /^\s*$/;
                my @tmp=split/\t+/;
                push@inputs,\@tmp;
                $i++;
        }
        $/="》";
        open HH,">$outHtml" or die "$!";
	my $titles=basename $outHtml;
	$titles=~s/\.html//;
        print HH <<HTML;
        <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
        <html lang="zh_CN" xmlns="http://www.w3.org/1999/xhtml"><head><title>$title</title>
        <meta charset="UTF-8"></meta>
        <!--[if lt IE 9]>
        <script src="$srcPath/js/html5shiv.min.js"></script><script src="$srcPath/js/respond.min.js"></script>
        <![endif]-->
        <meta content="IE=edge" http-equiv="X-UA-Compatible"></meta>
        <meta content="width=device-width, initial-scale=1" name="viewport"></meta>
        <link href="$srcPath/css/bootstrap.min.css" type="text/css" rel="stylesheet" />
        <link href="$srcPath/css/index.css" type="text/css" rel="stylesheet" />
        <link href="$srcPath/js/fancyBox/jquery.fancybox.css" type="text/css" rel="stylesheet" />
        <link href="$srcPath/css/nav.css" type="text/css" rel="stylesheet" />
        <link href="$srcPath/css/raxus.css" type="text/css" rel="stylesheet" />
        <script src="$srcPath/js/jquery-1.11.3.min.js" type="text/javascript"></script>
        <script src="$srcPath/js/nav.js" type="text/javascript"></script>
        <script src="$srcPath/js/raxus-slider.min.js" type="text/javascript"></script>
        <script src="$srcPath/js/fancyBox/jquery.fancybox.pack.js" type="text/javascript"></script>
        <script src="$srcPath/js/fancyBox/jquery.mousewheel-3.0.6.pack.js" type="text/javascript"></script>
        <script src="$srcPath/js/bootstrap.min.js" type="text/javascript"></script>
        <script src="$srcPath/js/ready.js" type="text/javascript"></script>
        <script src="$srcPath/js/scrolltop.js" type="text/javascript"></script>
        </head>
        <body>
        <div class="container shadow"><header><img src="$srcPath/images/logo.jpg" class="pull-right" />
        <div role="main" ><header><h2 id="title" class="text-center">$title</h2>
        </header>
        </div>
HTML
                if($text){
                        print HH "<div class=\"table-responsive\"><p>$text</p></div>\n";
                }
                print HH "<div class=\"table-responsive\"><table class=\"table table-bordered table-hover table-striped\"><thead><tr class=\"bg-info\">\n";
                for (my $i=0;$i<=$#{$inputs[0]};$i++){
                        print HH "<th nowrap>$inputs[0][$i]</th>\n";
                }
                print HH "</tr></thead>\n<tbody>\n";
                for (my $k=1;$k<=$#inputs ;$k++) {
                        print HH "<tr>";
                        for (my $i=0;$i<=$#{$inputs[$k]};$i++){
                                if($linkColNum){
                                        my $j=$i+1;
                                        if($linkColNum=~/,$j,/){
#print "$titles\t$inputs[$k][$i]\t$$linkHash{$titles}{$inputs[$k][$i]}\n";
                                                print HH "<td nowrap><a href=\"$$linkHash{$titles}{$inputs[$k][$i]}\" target=\"_blank\">$inputs[$k][$i]</a></td>";
                                        }else{
                                                print HH "<td nowrap>$inputs[$k][$i]</td>";
                                        }
                                }else{
                                        print HH "<td nowrap>$inputs[$k][$i]</td>";
                                }
                        }
                        print HH "</tr>\n";
                }
print HH <<XGL;
        </tbody>
        </table>
        </body>
        </html>
XGL
        close HH;
}



sub USAGE{
        my $usage=<<"USAGE";
Program: $0
Version: 1.0.0
Contact: wenyh\@biomarker.com.cn
Usage:
        Options:
	-deg		<path>	input BMK_DEG_Analysis path, forced
	-density	<path>	input DIR, Contained fpkm density and cor png
	-cfg		<file>	input detail cfg
	-type		<str>	gene/circRNA/lncRNA/miRNA, default gene
	-o		<file>	output xml file
        -h      Help

Example: perl $0 -deg BMK_*_RNA/BMK_*_DEG_Analysis -density BMK_*_Expression/PNG -cfg detail.cfg -type gene/circRNA/lncRNA/miRNA -o .

USAGE
        print $usage;
        exit;
}
