#修订时间：2019年11月19日
# 去掉不必要的度量
#
#

#修订时间: 2008年7月28日

# Synopsis:   compute complexity, cohesion, coupling, inheritance, and size metrics for each class in project
#
# Language: C++, Java
#
# Description:
#  计算类的复杂性/内聚性/耦合性/规模/继承等相关度量 
#  For the latest Understand perl API documentation, see 
#      http://www.scitools.com/perl/
#  Refer to the documenation for details on using the perl API 
#  with Understand and for details on all Understand perl API calls.

# 速度块的版本: (1) 耦合性度量单独放在外面计算, 总的复杂性为O(N), N为数据库中类的数目
#               (2) 继承相关的度量集中在一个子程序中计算, 只需要查一次祖先类/后裔类, 复合性度量利用先前的计算结果
# 主要问题: 结构不甚清晰, 不便于复用到其他应用中 

use strict;
use Understand;
use Getopt::Long;
use File::Basename;
use IO::File;
use POSIX qw(tmpnam);
use Env;
use File::Find;

autoflush STDOUT 1;

# Usage:
sub usage
{
    return << "END_USAGE";
${ \( shift @_ ) }
usage: computeChangeProness -prev database -out file
 -prev database             Specify Understand database (required for uperl, inherited from Understand)
 -out file                  (optional)Output file, default is "D:/test.csv" 
END_USAGE
}

my %opts=( 
    db => "D:/workspace/mixed-workspace/mySZZ/GetMetrics/udb/kafka/kafka-2.1.1.udb",
    out => 'D:/workspace/mixed-workspace/mySZZ/GetMetrics/metrics/kafka/test.csv',
    help => '',
    );

# my $dbPath;
# my $comma;
# my $help;
GetOptions(
     "db=s" => \$opts{db},
     "out=s" => \$opts{out},
     "help" => \$opts{help},
           );

use FileHandle;
my $outputFileName = $opts{out};
my $outputFH = new FileHandle(">  ".$outputFileName);

# help message
die usage("") if ($opts{help});
die usage("database specification required") if (!$opts{db});

# insist the it not be run from within the GUI
if ( Understand::Gui::active() ) {
    die usage("This script is not designed to be called from the GUI");
}

# make sure db files are readable before continuing on
die "Can't read database " . $opts{'db'} if ( $opts{db} && ! -r $opts{db} );

# open the database 
my $db=openDatabase($opts{db});

#debug options
my $debug = 0;

#全局变量
my %allClassNameHash; #数据库中所有的类, key为类名




# verify supported language
my $language = $db->language();
if ($language !~ /ada|c|java/i) {
    closeDatabase($db);
    die "$language is currently unsupported";
}


my $sep = ",";
my $totalClasses = 0;

print "\nhi, I am computing ",$opts{db}, " please wait ... \n";

my ($isConstructor, $isDestructor, $isAccessOrDelegationMethod) = initialSpecialMethod($language);

# get sorted class entities list
#只计算最外层的类, 即不统计那些嵌套在其他类中的类
my @tempclasses = $db->ents("class ~unknown ~unresolved");
my @classes;

print "total = ", scalar @tempclasses, "\n";


foreach my $class (@tempclasses){
	 print "standar class = ", $class->name(), "\n" if ($class->library() =~ m/Standard/i);
   next if ($class->library() =~ m/Standard/i);
   
	 next if ($class->ref("definein", "class"));
	 next if ($class->ref("definein", "interface"));
	 next if ($class->ref("definein", "method"));     # Java的方法可能会定义匿名的类(通常发生在返回语句中)
	 next if ($class->ref("definein", "function"));
	 
	 my ($startRef) = $class->refs("definein", "", 1); #understand有可能将根本没有定义的类包括进来, 原因未知
	 my ($endRef) = $class->refs("end","",1);		
	 next if (!$startRef || !$endRef);
	   
	 push @classes, $class;
	 
	 my $classKey = getClassKey($class); 
	 $allClassNameHash{$classKey} = $class;  #记录数据库中所有的类
}


my $metricsList = availableMetrics();

my @complexityMetricNameList = (sort keys %{$metricsList->{Complexity}});
my @sizeMetricNameList = (sort keys %{$metricsList->{Size}});
my @InheritanceMetricNameList = (sort keys %{$metricsList->{Inheritance}});
my @cohesionMetricNameList = (sort keys %{$metricsList->{Cohesion}});
my @couplingMetricNameList = (sort keys %{$metricsList->{Coupling}});
my @otherMetricNameList = (sort keys %{$metricsList->{Other}});

print $outputFH ("relName".$sep."className".$sep.join($sep, @complexityMetricNameList)
                                .$sep.join($sep, @sizeMetricNameList)
                                .$sep.join($sep, @InheritanceMetricNameList)
                                # .$sep.join($sep, @cohesionMetricNameList)
                                .$sep.join($sep, @couplingMetricNameList)
                                # .$sep.join($sep, @otherMetricNameList)
                                , "\n");
# print $outputFH ("name_id".$sep.join($sep, @complexityMetricNameList)
#                                 .$sep.join($sep, @sizeMetricNameList)
#                                 .$sep.join($sep, @InheritanceMetricNameList)
#                                 # .$sep.join($sep, @cohesionMetricNameList)
#                                 .$sep.join($sep, @couplingMetricNameList)
#                                 # .$sep.join($sep, @otherMetricNameList)
#                                 , "\n");


print "total classes = ", scalar @classes, "\n";
print "total in hash = ", scalar (keys %allClassNameHash), "\n";


#my $BriandCouplingMetrics = getBriandCouplingMetrics(\%allClassNameHash);  #单独计算Briand等提出的18种耦合性度量
my $BriandCouplingMetrics = {};


foreach my $class (sort {$a->longname() cmp $b->longname();}@classes) {
	$totalClasses++;   

  print "\nNo = ", $totalClasses, " / ", scalar @classes;
  # print "\t class = ", $class->name(), "\n"; 
	
	my $metricsList = availableMetrics();	   #这一句必须要
	computeMetrics($class, \%allClassNameHash, $BriandCouplingMetrics, $metricsList);	

	# print $outputFH ($class->ref()->file()->relname());
	print $outputFH ($class->ref()->file()->relname(), $sep);
	print $outputFH ($class->longname());
	
	foreach my $metric (sort keys %{$metricsList->{Complexity}}){
		print $outputFH ($sep, $metricsList->{Complexity}->{$metric});
	}

	foreach my $metric (sort keys %{$metricsList->{Size}}){
		print $outputFH ($sep, $metricsList->{Size}->{$metric});
	}

	foreach my $metric (sort keys %{$metricsList->{Inheritance}}){
		print $outputFH ($sep, $metricsList->{Inheritance}->{$metric});
	}
	
	foreach my $metric (sort keys %{$metricsList->{Cohesion}}){
		print $outputFH ($sep, $metricsList->{Cohesion}->{$metric});
	}

	foreach my $metric (sort keys %{$metricsList->{Coupling}}){
		print $outputFH ($sep, $metricsList->{Coupling}->{$metric});
	}

	foreach my $metric (sort keys %{$metricsList->{Other}}){
		print $outputFH ($sep, $metricsList->{Other}->{$metric});
	}
	
	print $outputFH ("\n");
}



# my $totalSLOC = $db->metric("CountLineCode");
# print $outputFH ("\n Total SLOC in this project:  ", $totalSLOC, "\n");


close($outputFH);
closeDatabase($db);



sub initialSpecialMethod{	
	my $sLanguage = shift;
	
	my ($isConstr, $isDestr, $isAccOrDel);
	
	if ($sLanguage =~ /c/i){
    #	print "language is C++! \n";
	  $isConstr = \&isCPlusPlusConstructor;
	  $isDestr = \&isCPlusPlusDestructor;
	  $isAccOrDel = \&isCPlusPlusAccessOrDelegationMethod;
  }
  elsif ($sLanguage =~ /java/i){
    #	print "language is Java! \n";	
	  $isConstr = \&isJavaConstructor;
	  $isDestr = \&isJavaDestructor;
	  $isAccOrDel = \&isJavaAccessOrDelegationMethod;
  }
  
  return ($isConstr, $isDestr, $isAccOrDel);
}


sub availableMetrics{
	my $hashMetrics = {};
	
  #complexity metrics
  $hashMetrics->{Complexity}->{CDE} = "undef";        #Class Definition Entropy
  $hashMetrics->{Complexity}->{CIE} = "undef";        #Class Implementation Entropy
  $hashMetrics->{Complexity}->{WMC} = "undef";        #Weighted Method Per Class    
  $hashMetrics->{Complexity}->{SDMC} = "undef";       #Standard Deviation Method Complexity
  $hashMetrics->{Complexity}->{AvgWMC} = "undef";     #Average Weight Method Complexity
  $hashMetrics->{Complexity}->{CCMax} = "undef";      #Maximum cyclomatic complexity of a single method of a class
  $hashMetrics->{Complexity}->{NTM} = "undef";        #Number of Trival Methods  
#  $hashMetrics->{Complexity}->{CC1} = "undef";        #Class Complexity one. From: Y.S. Lee, B.S. Liang, F.J. Wang. Some complexity metrics for OO programs based on information flow. 
#  $hashMetrics->{Complexity}->{CC2} = "undef";        #Class Complexity Two. From: Y.S. Lee, B.S. Liang, F.J. Wang. Some complexity metrics for OO programs based on information flow. 
#  $hashMetrics->{Complexity}->{CC3} = "undef";        #Class Complexity Three. From: K. Kim, Y. Shin, C. Wu. Complexity measures for OO program based on the entropy
  
                      
  #coupling metrics
  $hashMetrics->{Coupling}->{CBO} = "undef";          #Coupling Between Object              
  # $hashMetrics->{Coupling}->{RFC} = "undef";          #Response For a Class, 包括自身顶的方法和所有直接或者间接调用的方法
 # $hashMetrics->{Coupling}->{RFC1} = "undef";         #Response For a Class, 只包括自身定义的方法和直接调用的方法
  # $hashMetrics->{Coupling}->{MPC} = "undef";          #Message Passing Coupling
  $hashMetrics->{Coupling}->{DAC} = "undef";          #Data Abstraction Coupling: 类型是其他类的属性数目
  $hashMetrics->{Coupling}->{DACquote} = "undef";     #Data Abstraction Coupling: 类型是其他类的类的数目
  $hashMetrics->{Coupling}->{ICP} = "undef";          #Information-flow-based Coupling
  $hashMetrics->{Coupling}->{IHICP} = "undef";        #Information-flow-based inheritance Coupling
  $hashMetrics->{Coupling}->{NIHICP} = "undef";       #Information-flow-based non-inheritance Coupling
#  $hashMetrics->{Coupling}->{IFCAIC} = "undef";       #Inverse friends class-attribute interaction import coupling
#  $hashMetrics->{Coupling}->{ACAIC} = "undef";        #Ancestor classes class-attribute interaction import coupling
#  $hashMetrics->{Coupling}->{OCAIC} = "undef";        #Others class-attribute interaction import coupling
#  $hashMetrics->{Coupling}->{FCAEC} = "undef";        #Friends class-attribute interaction export coupling
#  $hashMetrics->{Coupling}->{DCAEC} = "undef";        #Descendents class class-attribute interaction export coupling
#  $hashMetrics->{Coupling}->{OCAEC} = "undef";        #Others class-attribute interaction export coupling
#  $hashMetrics->{Coupling}->{IFCMIC} = "undef";       #Inverse friends class-method interaction import coupling
#  $hashMetrics->{Coupling}->{ACMIC} = "undef";        #Ancestor class class-method interaction import coupling
#  $hashMetrics->{Coupling}->{OCMIC} = "undef";        #Others class-method interaction import coupling
#  $hashMetrics->{Coupling}->{FCMEC} = "undef";        #Friends class-method interaction export coupling
#  $hashMetrics->{Coupling}->{DCMEC} = "undef";        #Descendents class-method interaction export coupling
#  $hashMetrics->{Coupling}->{OCMEC} = "undef";        #Others class-method interaction export coupling
#  $hashMetrics->{Coupling}->{OMMIC} = "undef";        #Others method-method interaction import coupling
#  $hashMetrics->{Coupling}->{IFMMIC} = "undef";       #Inverse friends method-method interaction import coupling
#  $hashMetrics->{Coupling}->{AMMIC} = "undef";        #Ancestor class method-method interaction import coupling
#  $hashMetrics->{Coupling}->{OMMEC} = "undef";        #Others method-method interaction export coupling
#  $hashMetrics->{Coupling}->{FMMEC} = "undef";        #Friends method-method interaction export coupling
#  $hashMetrics->{Coupling}->{DMMEC} = "undef";        #Descendents method-method interaction export coupling
#  $hashMetrics->{Coupling}->{CBI} = "undef";          #Degree of coupling of inheritance. From: E.M. Kim, S. Kusumoto, T. Kikuno. Heuristics for computing attribute values of C++ program complexity metrics. COMPSAC 1996: 104-109.  
#  $hashMetrics->{Coupling}->{UCL} = "undef";          #Number of classes used in a class except for ancestors and children. From: E.M. Kim, S. Kusumoto, T. Kikuno. Heuristics for computing attribute values of C++ program complexity metrics. COMPSAC 1996: 104-109.  
  # $hashMetrics->{Coupling}->{MPCNew} = "undef";       #Number of send statements in a class. From: E.M. Kim, S. Kusumoto, T. Kikuno. Heuristics for computing attribute values of C++ program complexity metrics. COMPSAC 1996: 104-109.  
#  $hashMetrics->{Coupling}->{CC} = "undef";           #Class Coupling. From: C. Rajaraman, M.R. Lyu. Reliability and maintainability related software coupling metrics in C++ programs.
#  $hashMetrics->{Coupling}->{AMC} = "undef";          #Average Method Coupling. From: C. Rajaraman, M.R. Lyu. Reliability and maintainability related software coupling metrics in C++ programs.


  #inheritance metrics
  $hashMetrics->{Inheritance}->{NOC} = "undef";       #Number Of Child Classes
  $hashMetrics->{Inheritance}->{NOP} = "undef";       #Number Of Parent Classes
  $hashMetrics->{Inheritance}->{DIT} = "undef";       #Depth of Inheritance Tree
  $hashMetrics->{Inheritance}->{AID} = "undef";       #Average Inheritance Depth of a class(L.C.Briand, et al. Exloring the relationships between design measures and software quality in OO systems. JSS, vol. 51, 2000: 245-273.
  $hashMetrics->{Inheritance}->{CLD} = "undef";       #Class-to-Leaf Depth
  $hashMetrics->{Inheritance}->{NOD} = "undef";       #Number Of Descendents
  $hashMetrics->{Inheritance}->{NOA} = "undef";       #Number Of Ancestors
  $hashMetrics->{Inheritance}->{NMO} = "undef";       #Number of Methods Overridden
  $hashMetrics->{Inheritance}->{NMI} = "undef";       #Number of Methods Inherited
  $hashMetrics->{Inheritance}->{NMA} = "undef";       #Number Of Methods Added
  $hashMetrics->{Inheritance}->{SIX} = "undef";       #Specialization IndeX   =  NMO * DIT / (NMO + NMA + NMI)
  $hashMetrics->{Inheritance}->{PII} = "undef";       #Pure Inheritance Index. From: B.K. Miller, P. Hsia, C. Kung. Object-oriented architecture measures. 32rd Hawaii International Conference on System Sciences 1999    
  $hashMetrics->{Inheritance}->{SPA} = "undef";       #static polymorphism in ancestors
  $hashMetrics->{Inheritance}->{SPD} = "undef";       #static polymorphism in decendants
  $hashMetrics->{Inheritance}->{DPA} = "undef";       #dynamic polymorphism in ancestors
  $hashMetrics->{Inheritance}->{DPD} = "undef";       #dynamic polymorphism in decendants
  $hashMetrics->{Inheritance}->{SP} = "undef";        #static polymorphism in inheritance relations
  $hashMetrics->{Inheritance}->{DP} = "undef";        #dynamic polymorphism in inheritance relations
#  $hashMetrics->{Inheritance}->{CHM} = "undef";       #Class hierarchy metric. From J.Y. Chen, J.F. Lu. A new metric for OO design. IST, 35(4): 1993.
#  $hashMetrics->{Inheritance}->{DOR} = "undef";       #Degree of reuse by inheritance. From: E.M. Kim, S. Kusumoto, T. Kikuno. Heuristics for computing attribute values of C++ program complexity metrics. COMPSAC 1996: 104-109.

  
  #size metrics 
  $hashMetrics->{Size}->{NMIMP} = "undef";     #Number Of Methods Implemented in a class
  $hashMetrics->{Size}->{NAIMP} = "undef";     #Number Of Attributes Implemented in a class
  $hashMetrics->{Size}->{loc}  = "undef";     #source lines of code
#  $hashMetrics->{Size}->{SLOCExe} = "undef";   #source lines of executable code
  $hashMetrics->{Size}->{stms}  = "undef";     #number of statements
#  $hashMetrics->{Size}->{stmsExe} = "undef";   #number of executable statements
  $hashMetrics->{Size}->{NM} = "undef";        #number of all methods (inherited, overriding, and non-inherited) methods of a class
  $hashMetrics->{Size}->{NA} = "undef";        #number of attributes in a class, both inherited and non-inherited
  $hashMetrics->{Size}->{Nmpub} = "undef";     #number of public methods implemented in a class
  $hashMetrics->{Size}->{NMNpub} = "undef";    #number of non-public methods implemented in a class
  $hashMetrics->{Size}->{NumPara} = "undef";   #sum of the number of parameters of the methods implemented in a class
  $hashMetrics->{Size}->{NIM} = "undef";       #Number of Instance Methods
  $hashMetrics->{Size}->{NCM} = "undef";       #Number of Class Methods
  $hashMetrics->{Size}->{NLM} = "undef";       #Number of Local Methods
  $hashMetrics->{Size}->{AvgSLOC} = "undef";   #Average Source Lines of Code
#  $hashMetrics->{Size}->{AvgSLOCExe} = "undef";#Average Source Lines of Executable Code

  #cohesion metrics
  # $hashMetrics->{Cohesion}->{LCOM1} = "undef";
  # $hashMetrics->{Cohesion}->{LCOM2} = "undef";
  # $hashMetrics->{Cohesion}->{LCOM3} = "undef";
  # $hashMetrics->{Cohesion}->{LCOM4} = "undef";
  # $hashMetrics->{Cohesion}->{Co}    = "undef";
#  $hashMetrics->{Cohesion}->{NewCo} = "undef";
  # $hashMetrics->{Cohesion}->{LCOM5} = "undef";
#  $hashMetrics->{Cohesion}->{NewLCOM5} = "undef";  #also called NewCoh/Coh
  # $hashMetrics->{Cohesion}->{LCOM6} = "undef";     #based on parameter names. From: J.Y. Chen, J.F. Lu. A new metric for OO design. IST, 35(4): 1993.
  # $hashMetrics->{Cohesion}->{LCC}   = "undef";     #Loose Class Cohesion
  # $hashMetrics->{Cohesion}->{TCC}   = "undef";     #Tight Class Cohesion   
  # $hashMetrics->{Cohesion}->{ICH}   = "undef";     #Information-flow-based Cohesion
  # $hashMetrics->{Cohesion}->{DCd}   = "undef";     #Degree of Cohesion based Direct relations between the public methods 
  # $hashMetrics->{Cohesion}->{DCi}   = "undef";     #Degree of Cohesion based Indirect relations between the public methods
#  $hashMetrics->{Cohesion}->{CBMC}  = "undef";   
#  $hashMetrics->{Cohesion}->{ICBMC} = "undef"; 
#  $hashMetrics->{Cohesion}->{ACBMC} = "undef"; 
#  $hashMetrics->{Cohesion}->{C3}    = "undef"; 
#  $hashMetrics->{Cohesion}->{LCSM}  = "undef";     #Lack of Conceptual similarity between Methods
  # $hashMetrics->{Cohesion}->{OCC}   = "undef";     #Opitimistic Class Cohesion
  # $hashMetrics->{Cohesion}->{PCC}   = "undef";     #Pessimistic Class Cohesion
  # $hashMetrics->{Cohesion}->{CAMC}  = "undef";     #Cohesion Among Methods in a Class
#  $hashMetrics->{Cohesion}->{iCAMC} = "undef";     #包含方法返回值类型的CAMC
#  $hashMetrics->{Cohesion}->{CAMCs} = "undef";     #包含self类型的CAMC
#  $hashMetrics->{Cohesion}->{iCAMCs}= "undef";     #包含方法返回值类型和self类型的CAMC
  # $hashMetrics->{Cohesion}->{NHD}   = "undef";     #Normalized Hamming Distance metric
#  $hashMetrics->{Cohesion}->{iNHD}  = "undef";  
#  $hashMetrics->{Cohesion}->{NHDs}  = "undef"; 
#  $hashMetrics->{Cohesion}->{iNHDs} = "undef";     
  # $hashMetrics->{Cohesion}->{SNHD}  = "undef";     
#  $hashMetrics->{Cohesion}->{iSNHD}  = "undef";     
#  $hashMetrics->{Cohesion}->{SNHDs}  = "undef";    
#  $hashMetrics->{Cohesion}->{iSNHDs}  = "undef";    
  # $hashMetrics->{Cohesion}->{SCOM}  = "undef";     #Sensitive Class Cohesion Metric. From: International Journal of Information Theories & Applications. Vol. 13, No. 1, 2006: 82-91 
  # $hashMetrics->{Cohesion}->{CAC}  = "undef";      #Class Abstraction Cohesion. From: B.K. Miller, P. Hsia, C. Kung. Object-oriented architecture measures. 32rd Hawaii International Conference on System Sciences 1999

  #Other metrics
  # $hashMetrics->{Other}->{OVO} = "undef";          #parametric overloading metric 
  # $hashMetrics->{Other}->{MI} = "undef";        #Maintainability Index

 
  return $hashMetrics;
} # End sub defineMetrics



sub computeMetrics{
	my $sClass = shift;
	my $sAllClassNameHash = shift;
	my $sBriandCouplingMetrics = shift;	
	my $hashMetrics = shift;

  #-----------------计算一些共用的数据, 以提高计算效率--------------------------
  	my %ancestorHash = ();
  	my $ancestorLevel;
  	$ancestorLevel = getAncestorClasses($sClass, \%ancestorHash); 	
  
  	my %descendentClassHash;
  	getDescendentClasses($sClass, \%descendentClassHash);



	# $hashMetrics->{Size}->{NMIMP} = NMIMP($sClass); 
	# $hashMetrics->{Size}->{NAIMP} = NAIMP($sClass); 

   
  #----------------compute complexity metrics------------------------
  
  	# my $start = getTimeInSecond();
  	$hashMetrics->{Complexity}->{CDE} = CDE($sClass);
  	# reportComputeTime($start, "CDE");  
  
  	# $start = getTimeInSecond();
  	$hashMetrics->{Complexity}->{CIE} = CIE($sClass);
  	# reportComputeTime($start, "CIE");  
  
  	$hashMetrics->{Complexity}->{WMC} = WMC($sClass);
 	  $hashMetrics->{Complexity}->{SDMC} = SDMC($sClass);
  	$hashMetrics->{Complexity}->{AvgWMC} = AvgWMC($sClass);
  	$hashMetrics->{Complexity}->{CCMax} = CCMax($sClass);
  	$hashMetrics->{Complexity}->{NTM} = NTM($sClass);
  
#  	$start = getTimeInSecond();
#  	my ($valueCC1, $valueCC2, $valueCC3) = CComplexitySerires($sClass, \%ancestorHash, $ancestorLevel); 
#  	$hashMetrics->{Complexity}->{CC1} = $valueCC1;
#  	$hashMetrics->{Complexity}->{CC2} = $valueCC2;
#  	$hashMetrics->{Complexity}->{CC3} = $valueCC3;
#  	reportComputeTime($start, "CC1, CC2, CC3");  
  

    
  #----------------compute coupling metrics------------------------  
	$hashMetrics->{Coupling}->{CBO} = $sClass->metric("CountClassCoupled");
	
	# $start = getTimeInSecond();
	# $hashMetrics->{Coupling}->{RFC} = RFC($sClass, \%ancestorHash, $ancestorLevel);
#	$hashMetrics->{Coupling}->{RFC1} = RFC1($sClass, \%ancestorHash, $ancestorLevel);
	# reportComputeTime($start, "RFC");  
	
	# $start = getTimeInSecond();
	# ($hashMetrics->{Coupling}->{MPC}, $hashMetrics->{Coupling}->{MPCNew}) = MPCSeries($sClass, $sAllClassNameHash);
	# reportComputeTime($start, "MPC");  
	
	# $start = getTimeInSecond();
	($hashMetrics->{Coupling}->{DAC}, $hashMetrics->{Coupling}->{DACquote}) = DAC($sClass, $sAllClassNameHash);
	# reportComputeTime($start, "DAC");  
	
	# $start = getTimeInSecond();
	my $valueICP = ICP($sClass, $sAllClassNameHash);
	$hashMetrics->{Coupling}->{ICP} = $valueICP;	
	my $valueIHICP = IHICP($sClass, \%ancestorHash);
	$hashMetrics->{Coupling}->{IHICP} = $valueIHICP;
	# reportComputeTime($start, "ICP");  
	
	$hashMetrics->{Coupling}->{NIHICP} = NIHICP($valueICP, $valueIHICP);	
	
	my $classKey = getClassKey($sClass);
	
#	$hashMetrics->{Coupling}->{IFCAIC} = $sBriandCouplingMetrics->{$classKey}->{IFCAIC};
#	$hashMetrics->{Coupling}->{ACAIC} = $sBriandCouplingMetrics->{$classKey}->{ACAIC};
#	$hashMetrics->{Coupling}->{OCAIC} = $sBriandCouplingMetrics->{$classKey}->{OCAIC};
#	$hashMetrics->{Coupling}->{FCAEC} = $sBriandCouplingMetrics->{$classKey}->{FCAEC};
#	$hashMetrics->{Coupling}->{DCAEC} = $sBriandCouplingMetrics->{$classKey}->{DCAEC};
#	$hashMetrics->{Coupling}->{OCAEC} = $sBriandCouplingMetrics->{$classKey}->{OCAEC};
#	$hashMetrics->{Coupling}->{IFCMIC} = $sBriandCouplingMetrics->{$classKey}->{IFCMIC};
#	$hashMetrics->{Coupling}->{ACMIC} = $sBriandCouplingMetrics->{$classKey}->{ACMIC};
#	$hashMetrics->{Coupling}->{OCMIC} = $sBriandCouplingMetrics->{$classKey}->{OCMIC};
#	$hashMetrics->{Coupling}->{FCMEC} = $sBriandCouplingMetrics->{$classKey}->{FCMEC};
#	$hashMetrics->{Coupling}->{DCMEC} = $sBriandCouplingMetrics->{$classKey}->{DCMEC};
#	$hashMetrics->{Coupling}->{OCMEC} = $sBriandCouplingMetrics->{$classKey}->{OCMEC};
#	$hashMetrics->{Coupling}->{IFMMIC} = $sBriandCouplingMetrics->{$classKey}->{IFMMIC};
#	$hashMetrics->{Coupling}->{AMMIC} = $sBriandCouplingMetrics->{$classKey}->{AMMIC};
#	$hashMetrics->{Coupling}->{OMMIC} = $sBriandCouplingMetrics->{$classKey}->{OMMIC};
#	$hashMetrics->{Coupling}->{FMMEC} = $sBriandCouplingMetrics->{$classKey}->{FMMEC};
#	$hashMetrics->{Coupling}->{DMMEC} = $sBriandCouplingMetrics->{$classKey}->{DMMEC};
#	$hashMetrics->{Coupling}->{OMMEC} = $sBriandCouplingMetrics->{$classKey}->{OMMEC};		
	
#	$start = getTimeInSecond();
#	$hashMetrics->{Coupling}->{CBI} = CBI($sClass, \%descendentClassHash);
#	reportComputeTime($start, "CBI");  
#	
#	$start = getTimeInSecond();
#	$hashMetrics->{Coupling}->{UCL} = UCL($sClass, $sAllClassNameHash, \%ancestorHash, \%descendentClassHash);
#	reportComputeTime($start, "UCL");  
#	
#	$start = getTimeInSecond();
#	($hashMetrics->{Coupling}->{CC}, $hashMetrics->{Coupling}->{AMC}) = CCAndAMC($sClass);
#	reportComputeTime($start, "CCandAMC");  
	
	#----------------compute inheritance metrics------------------------  
	# $start = getTimeInSecond();	
	InheritanceSeries($sClass, $sAllClassNameHash, \%ancestorHash, $ancestorLevel, \%descendentClassHash, $hashMetrics);
	# reportComputeTime($start, "InheritanceSeries");  
	

#	$start = getTimeInSecond();
#  	my $trtr = $sBriandCouplingMetrics->{totalNOD};  
#	my $valueDOR = DOR($sClass, $sAllClassNameHash, \%descendentClassHash, $trtr);
#	$hashMetrics->{Inheritance}->{DOR} = $valueDOR;
#	reportComputeTime($start, "DOR"); 
#	
		
	#----------------compute size metrics------------------------  
	$hashMetrics->{Size}->{NMIMP} = NMIMP($sClass); 
	$hashMetrics->{Size}->{NAIMP} = NAIMP($sClass); 
	$hashMetrics->{Size}->{loc} = UnderstandSLOC($sClass);
#	$hashMetrics->{Size}->{SLOCExe} = SLOCExe($sClass);
	$hashMetrics->{Size}->{stms} = $sClass->metric("CountStmt");
#	$hashMetrics->{Size}->{stmsExe} = $sClass->metric("CountStmtExe");
  $hashMetrics->{Size}->{NM} = NM($sClass, \%ancestorHash);
  $hashMetrics->{Size}->{NA} = NA($sClass, \%ancestorHash);
	$hashMetrics->{Size}->{Nmpub} = Nmpub($sClass);
	$hashMetrics->{Size}->{NMNpub} = NMNpub($sClass);
	$hashMetrics->{Size}->{NumPara} = NumPara($sClass);
	$hashMetrics->{Size}->{NIM} = NIM($sClass);
	$hashMetrics->{Size}->{NCM} = NCM($sClass);
	$hashMetrics->{Size}->{NLM} = NLM($sClass);
	$hashMetrics->{Size}->{AvgSLOC} = AvgSLOCPerMethod($sClass);
#	$hashMetrics->{Size}->{AvgSLOCExe} = AvgSLOCExePerMethod($sClass);

	
	#----------------compute cohesion metrics------------------------  
	# $start = getTimeInSecond();
	# LCOMSeriesAndCAC($sClass, $hashMetrics); #注意, 为了效率CAC也放在这里计算
	# TCCLCCSeries($sClass, $hashMetrics);
	# $hashMetrics->{Cohesion}->{ICH} = ICH($sClass);
	#CBMCSeries($sClass, $hashMetrics);
	# OCCAndPCC($sClass, $hashMetrics);
	# CAMCSeries($sClass, $hashMetrics);
	# reportComputeTime($start, "cohesion");
	
	# $start = getTimeInSecond();
	# $hashMetrics->{Cohesion}->{SCOM} = SCOM($sClass);
	# reportComputeTime($start, "SCOM");
	
#	$start = getTimeInSecond();
#	($hashMetrics->{Cohesion}->{C3}, $hashMetrics->{Cohesion}->{LCSM}) = C3($sClass);   
#	reportComputeTime($start, "C3");  
	
	
	#----------------compute other metrics------------------------  
	# $hashMetrics->{Other}->{OVO} = OVO($sClass);
	# $hashMetrics->{Other}->{MI} = MI($sClass);
	
	return $hashMetrics;	
} # End sub computeMetrics



sub RFC{
	my $sClass = shift;
	my $sAncestorHash = shift;
	my $sAncestorLevel = shift;	
	
	my %responseSet;	

  print "\t\t\t computing RFC..." if ($debug);
	
	my %totalMethods = (); #该类具有的所有方法: 继承非overriding的 + overriding + 新增加的
	
	#用当前类的方法和属性进行初始化
	my @methodArray = getEntsInClass($sClass, "define", "function ~unknown, method ~unknown");
	foreach my $func (@methodArray){
		my $signature = getFuncSignature($func, 1);
		$totalMethods{$signature} = $func;
		my $key = getLastName($sClass->name())."::".getFuncSignature($func, 1);				
		$responseSet{$key} = 1;		
	}
		
	#处理继承的方法
	foreach my $level (sort keys %{$sAncestorLevel}){
		my %ancestorHash = %{$sAncestorLevel->{$level}};
		
		foreach my $classKey (keys %ancestorHash){
			my $ancestorClass = $sAncestorHash->{$classKey};
			
			#----添加继承非overiding的方法-----------
			my @ancestorMethodArray = getEntsInClass($ancestorClass, "define", "function ~private ~unknown, method ~private ~unknown");
			foreach my $func (@ancestorMethodArray){
				my $signature = getFuncSignature($func, 1);
				next if (exists $totalMethods{$signature}); #被子孙类overriding了, 所以跳过
				$totalMethods{$signature} = $func;
				my $key = getLastName($ancestorClass->name())."::".getFuncSignature($func, 1);				
		    $responseSet{$key} = 1;
			}			
		}		
	}	
	
	

	my @allMethodArray = (values %totalMethods);
		
	
	while (@allMethodArray > 0){
		my $currentFunc = shift @allMethodArray;
		
		my %tempRS = ();
		PIM($currentFunc, \%tempRS);
		
		foreach my $currentKey (keys %tempRS){			
			next if (exists $responseSet{$currentKey});		#这一句很重要, 否则有可能造成死循环	
			
			$responseSet{$currentKey} = 1;
			push @allMethodArray, $tempRS{$currentKey}->{funcEnt};
		}
	}
	
	my $result = 0;	
	$result = (keys %responseSet);

  
#	foreach my $key (sort keys %responseSet){
#		print "\t\t", $key, "\n";
#	}
#	print "---------------------\n";
	
	print ".....RFC END\n" if ($debug);
	return $result;		
}#END sub RFC


sub RFC1{
	my $sClass = shift;
	my $sAncestorHash = shift;
	my $sAncestorLevel = shift;	

	my %responseSet;	

  print "\t\t\t computing RFC1..." if ($debug);
	
	my %totalMethods = (); #该类具有的所有方法: 继承非overriding的 + overriding + 新增加的
	
	#用当前类的方法和属性进行初始化
	my @methodArray = getEntsInClass($sClass, "define", "function ~unknown, method ~unknown");
	foreach my $func (@methodArray){
		my $signature = getFuncSignature($func, 1);
		$totalMethods{$signature} = $func;
		my $key = getLastName($sClass->name())."::".getFuncSignature($func, 1);				
		$responseSet{$key} = 1;		
	}
		
	#处理继承的方法
	foreach my $level (sort keys %{$sAncestorLevel}){
		my %ancestorHash = %{$sAncestorLevel->{$level}};
		
		foreach my $classKey (keys %ancestorHash){
			my $ancestorClass = $sAncestorHash->{$classKey};
			
			#----添加继承非overiding的方法-----------
			my @ancestorMethodArray = getEntsInClass($ancestorClass, "define", "function ~private ~unknown, method ~private ~unknown");
			foreach my $func (@ancestorMethodArray){
				my $signature = getFuncSignature($func, 1);
				next if (exists $totalMethods{$signature}); #被子孙类overriding了, 所以跳过
				$totalMethods{$signature} = $func;
				my $key = getLastName($ancestorClass->name())."::".getFuncSignature($func, 1);				
		    $responseSet{$key} = 1;
			}			
		}		
	}	
	
	

	my @allMethodArray = (values %totalMethods);
	
	foreach my $func (@allMethodArray){
		my %tempRS=();
		PIM($func, \%tempRS);
		
		foreach my $key (keys %tempRS){			
			$responseSet{$key} = 1;
		}
	}
		
	my $result = 0;
	
	$result = (keys %responseSet);
	
#	foreach my $key (sort keys %responseSet){
#		print "\t\t", $key, "\n";
#	}
#	print "---------------------\n";
	
	print "...RFC1 END\n" if ($debug);
	return $result;	
}#END sub RFC1



sub MPCSeries{
	my $sClass = shift;
	my $sAllClassNameHash = shift;
	
	print "\t\t\t computing MPCSeries..." if ($debug);

	my @methodArray = getRefsInClass($sClass, "define", "function ~unresolved ~unknown, method ~unresolved ~unknown");    
	
	my %calledMethodHash; #记录被当前方法调用的其他类中定义的方法. key是方法名, value是{Ent=>  , count => }
	                      #其中, Ent是方法实体, count是被调用的次数
  
  my $callingClassKey = getClassKey($sClass);
  
  my $valueMPC = 0;
  
  
  foreach my $method (@methodArray){
  	my @calledFuncSet = $method->ent()->refs("call", "function, method");
  	foreach my $func (@calledFuncSet){
  		my $calledClass = $func->ent()->ref("Definein", "Class");
  		next if (!$calledClass);  		  		
  		next if ($calledClass->ent()->library() =~ m/Standard/i);
  		
  		my $calledClassKey = getClassKey($calledClass->ent());
  		#next if (!exists $sAllClassNameHash->{$calledClassKey});  		
  		next if ($callingClassKey eq $calledClassKey); 
  		
  		$valueMPC++;  		
  		
  		my $methodSignature = getFuncSignature($func->ent(), 1);
  		my $key = $calledClassKey.$methodSignature;
  		
  		$calledMethodHash{$key}->{Ent} = $func->ent();
		
  		if (!exists $calledMethodHash{$key}){
  			$calledMethodHash{$key}->{Count} = 1;
  		}
  		else{
  			$calledMethodHash{$key}->{Count}++;
  		}  		
  	}
  }
  
  my $valueMPCNew = 0;
  
  foreach my $key (keys %calledMethodHash){
  	my $func = $calledMethodHash{$key}->{Ent};
  	my $count = $calledMethodHash{$key}->{Count};
  	
  	my $stmtNo = $func->metric("CountStmt");
  	
  	my $reserveWordsNo = getNoReserveWords($func);
  	
#  	print "\t\t calledFunc = ", $func->name(), "\n";
#  	print "\t\t count = ", $count, "\n";  	
#  	print "\t\t reserveWordsNo = ", $reserveWordsNo, "\n";  	
#  	print "\t\t stmtNo = ", $stmtNo, "\n";  
  	
  	$valueMPCNew = $valueMPCNew +  ($stmtNo + $reserveWordsNo) * $count;
  }
  
  
  print "...MPCSeries END\n" if ($debug);
  
  return wantarray? ($valueMPC, $valueMPCNew): $valueMPC;		
}#END sub MPCnew



sub DAC{
	my $sClass = shift;
	my $sAllClassNameHash = shift;
	
#	print "\t\t\t computing DAC...\n";
	
	my @attributeArray = getRefsInClass($sClass, "define","Member Object ~unknown ~unresolved, Member Variable ~unknown ~unresolved");
	
	my $valueDAC = 0;
	my $valueDACquote = 0;
	my %dacClassHash;
  
	foreach my $attribute (@attributeArray){
		my $attributeClass = $attribute->ent()->ref("Typed", "Class");
		
		next if (!$attributeClass);
		
#		print "\t\t attribute = ", $attribute->ent()->name(), "\n";
#		print "\t\t attribute Class = ", $attributeClass->ent()->name(), "\n";
		
		next if ($attributeClass->ent()->library() =~ m/Standard/i);
		
#		print "\t\t attribute = ", $attribute->ent()->name(), "\n";
#		print "\t\t classType = ", $attributeClass->ent()->name(), "\n";

		my $attributeClassKey = getClassKey($attributeClass->ent());		
		$dacClassHash{$attributeClassKey} = 1;
		#next if (!exists $sAllClassNameHash->{$attributeClassKey});		
		   
		$valueDAC++;   
	}
	
	$valueDACquote = scalar (keys %dacClassHash);
	
	return wantarray?($valueDAC, $valueDACquote): $valueDAC;
}#END sub DAC


sub ICP{
	my $sClass = shift;
	my $sAllClassNameHash = shift;
	
	my @methodArray = getEntsInClass($sClass, "define","function  ~unresolved ~unknown, method  ~unresolved ~unknown");    
	
	my $result = 0;
  
  my $callingClassKey = getClassKey($sClass);

  #只考虑动态的调用    
  foreach my $method (@methodArray){
  	my %polyCalledFuncSet;
  	PIM($method, \%polyCalledFuncSet);
  	
  	foreach my $key (sort keys %polyCalledFuncSet){
  		my $calledFuncEnt = $polyCalledFuncSet{$key}->{funcEnt};
  		my $callCount = $polyCalledFuncSet{$key}->{callCount};
  		
  		my $calledClass = $calledFuncEnt->ref("Definein", "Class");
  		next if (!$calledClass);		
  		next if ($calledClass->ent()->library() =~ m/Standard/i);
  		
  		my $calledClassKey = getClassKey($calledClass->ent());
  		#next if (!exists $sAllClassNameHash->{$calledClassKey});
  		
  		next if ($callingClassKey eq $calledClassKey);
  		
  		my @parameterSet = $calledFuncEnt->ents("Define", "Parameter");
  		
  		$result = $result + (@parameterSet + 1) * $callCount;  
  	}
  }
  
#  #只考虑静态的调用  
#  foreach my $method (@methodArray){
#  	my @calledFuncSet = $method->refs("call", "function  ~unresolved ~unknown, method  ~unresolved ~unknown");
#  	foreach my $func (@calledFuncSet){
#  		my $calledClass = $func->ent()->ref("Definein", "Class ~unknown ~unresovled");
#  		next if (!$calledClass);
#  		
#  		my $calledClassKey = getClassKey($calledClass->ent());
#  		
#     next if (!exists $sAllClassNameHash->{$calledClassKey});
#  		next if ($callingClassKey eq $calledClassKey);
#  		  		 
#  		my @parameterSet = $func->ent()->ents("Define", "Parameter");
#  		$result = $result + @parameterSet + 1;  		
#  	}
#  }
#  

  return $result;	
}#END sub ICP



sub IHICP{
	my $sClass = shift;
	my $sAncestorHash = shift;
	
	#计算祖先类的集合
	my %ancestorHash = %{$sAncestorHash};	#之所以用Hash表, 考虑多继承的情况
	
	#计算IHICP
	my @methodArray = getEntsInClass($sClass, "define","function  ~unresolved ~unknown, method  ~unresolved ~unknown");    
	
	my $result = 0; 

  #只考虑动态的调用    
  foreach my $method (@methodArray){
  	my %polyCalledFuncSet;
  	PIM($method, \%polyCalledFuncSet);
  	
  	foreach my $key (sort keys %polyCalledFuncSet){
  		my $calledFuncEnt = $polyCalledFuncSet{$key}->{funcEnt};
  		my $callCount = $polyCalledFuncSet{$key}->{callCount};
  		
  		my $calledClass = $calledFuncEnt->ref("Definein", "Class");
  		next if (!$calledClass);
  		next if ($calledClass->ent()->library() =~ m/Standard/i);
  		
  		my $calledClassKey = getClassKey($calledClass->ent());
  		next if (!exists $ancestorHash{$calledClassKey});
  		
  		my @parameterSet = $calledFuncEnt->ents("Define", "Parameter");
  		
  		$result = $result + (@parameterSet + 1) * $callCount;  
  	}
  }


#  #只考虑静态的调用 
#  foreach my $method (@methodArray){
#  	my @calledFuncSet = $method->refs("call", "function  ~unresolved ~unknown, method  ~unresolved ~unknown");
#  	foreach my $func (@calledFuncSet){
#  		my $calledClass = $func->ent()->ref("Definein", "Class ~unknown ~unresovled");
#  		next if (!$calledClass);
#  		next if ($calledClass->ent()->library() =~ m/Standard/i);
#  		
#  		my $calledClassKey = getClassKey($calledClass->ent());
#  		
#  		next if (!exists $ancestorHash{$calledClassKey});
#  		
#  		my @parameterSet = $func->ent()->ents("Define", "Parameter");  		
#  		$result = $result + @parameterSet + 1;  		
#  	}
#  }
  
  return $result;		
}#END sub IHICP


sub NIHICP{
  my $sICP = shift;
	my $sIHICP = shift;	
  
	my $result = $sICP - $sIHICP;	
	
	return $result;		
}#END sub NIHICP




sub getBriandCouplingMetrics{	
	my $sAllClassNameHash = shift;
	
	my $BriandCouplingMetrics = {}; #存放结果:  ->{类名}->{度量名} = value;
	
	my $CAInteractionMatrix = {}; #类间的类-属性交互矩阵
	my $CMInteractionMatrix = {}; #类间的类-方法交互矩阵
	my $MMInteractionMatrix = {}; #类间的方法-方法交互矩阵
	
	$CAInteractionMatrix->{myTotalSum} = 0; #保存总和, 以便计算一个类与other类的耦合性, such as OCAEC
	$CMInteractionMatrix->{myTotalSum} = 0;
	$MMInteractionMatrix->{myTotalSum} = 0;
	
	print "computing Briand Coupling metrics, please wait....\n";
	my $count = 0;
	
	foreach my $currentClassKey (keys %{$sAllClassNameHash}){
		my $currentClass = $sAllClassNameHash->{$currentClassKey};				
		
		print "Analyzing class ", $count, "...\n";
		$count++;
		
    #扫描类, 填充类-属性矩阵		
	  my @attributeArray = getRefsInClass($currentClass, "define","Member Object ~unknown ~unresolved, Member Variable ~unknown ~unresolved");	
	  my $result = 0;
  
	  foreach my $attribute (@attributeArray){
		  my $attributeClass = $attribute->ent()->ref("Typed", "Class");
		  next if (!$attributeClass);		
		  next if ($attributeClass->ent()->library() =~ m/Standard/i);

      my $attributeClassKey = getClassKey($attributeClass->ent());
   		
   		#next if (!exists $sAllClassNameHash->{$attributeClassKey}); #如果不是应用类, 则跳过   		
   		next if ($attributeClassKey eq $currentClassKey); #因为是耦合, 所以只考虑当前类与其它类之间的关系

   		$CAInteractionMatrix->{Matrix}->{$currentClassKey}->{$attributeClassKey}++;   		
   		$CAInteractionMatrix->{myTotalSum}++;		
   	}
   	
   	
   	#++++++++++++++++++扫描类, 填充类-方法矩阵++++++++++++++++++++++		
   	my %addedMethodHash; 
	  getAddedMethods($currentClass, \%addedMethodHash);
	
	  foreach my $key (keys %addedMethodHash){
		  my $func = $addedMethodHash{$key};		
		  my @parameters = $func->ents("Define", "Parameter");		
		  #分析方法的每个参数的类型
		  foreach my $para (@parameters){			
			  my $parameterClass = $para->ref("Typed", "Class");			
			  next if (!$parameterClass);			  			
			  next if ($parameterClass->ent()->library() =~ m/Standard/i);

        my $parameterClassKey = getClassKey($parameterClass->ent());
			  
			  #next if (!exists $sAllClassNameHash->{$parameterClassKey}); #如果不是应用类, 则跳过
			  next if ($parameterClassKey eq $currentClassKey); #因为是耦合, 所以只考虑当前类与其它类之间的关系
			  
			  $CMInteractionMatrix->{Matrix}->{$currentClassKey}->{$parameterClassKey}++;
   		  $CMInteractionMatrix->{myTotalSum}++;				  
		  }
		  
		
		  #分析方法的返回类型
		  my $returnClass = $func->ref("Typed", "Class");			
			next if (!$returnClass);			  					  
			next if ($returnClass->ent()->library() =~ m/Standard/i);
    
		  my $returnClassKey = getClassKey($returnClass->ent());
		  
			#next if (!exists $sAllClassNameHash->{$returnClassKey}); #如果不是应用类, 则跳过
			next if ($returnClassKey eq $currentClassKey); #因为是耦合, 所以只考虑当前类与其它类之间的关系		  
			
			$CMInteractionMatrix->{Matrix}->{$currentClassKey}->{$returnClassKey}++;
   		$CMInteractionMatrix->{myTotalSum}++;
	  }
   	
   	
   	#++++++++++++++++++扫描类, 填充方法-方法矩阵++++++++++++++++++++++		
  	my @methodArray = getRefsInClass($currentClass, "define", "function ~unresolved ~unknown, method ~unresolved ~unknown");    	
	
    #统计以当前类中调用其他类中方法的方法数目
    foreach my $method (@methodArray){
  		my @calledFuncSet = $method->ent()->refs("call", "function ~unresolved ~unknown, method ~unresolved ~unknown");
  	  foreach my $func (@calledFuncSet){
  		  my $calledClass = $func->ent()->ref("Definein", "Class");
  			next if (!$calledClass);  		  		
  			next if ($calledClass->ent()->library() =~ m/Standard/i);
  			
  			my $calledClassKey = getClassKey($calledClass->ent()); 
  		
  			#next if (!exists $sAllClassNameHash->{$calledClassKey}); #如果不是应用类, 则跳过
  			next if ($calledClassKey eq $currentClassKey); #因为是耦合, 所以只考虑当前类与其它类之间的关系	
  			
  			$MMInteractionMatrix->{Matrix}->{$currentClassKey}->{$calledClassKey}++;
   			$MMInteractionMatrix->{myTotalSum}++;
  		}
  		
  		#统计以$sClassD中方法为参数的(类$sClassC)方法数目
  		#待补充....
 	  }  
  }

  #---------------------计算18种耦合性度量--------------------		  
	BriandCouplingSeries($sAllClassNameHash, $CAInteractionMatrix, $CMInteractionMatrix, $MMInteractionMatrix, 
	                     $BriandCouplingMetrics);
	
	return $BriandCouplingMetrics;
}#END sub getBriandCouplingMetrics



sub BriandCouplingSeries{
	#放在一起计算, 以便节省查找祖先类, 子孙类, 友元类, 逆向友元类, 以及其它类的时间
	my $sAllClassNameHash = shift;
	my $sClassAttributeMatrix = shift;
	my $sClassMethodMatrix = shift;
	my $sMethodMethodMatrix = shift;
	my $sBriandCouplingMetrics = shift; 
	
	
#	print "CA matrix: \n";
#	
#	print "\total sum = ", $sClassAttributeMatrix->{myTotalSum}, "\n";
#	foreach my $source (keys %{$sClassAttributeMatrix->{Matrix}}){
#		my %tempHash = %{$sClassAttributeMatrix->{Matrix}->{$source}};
#		foreach my $dest (keys %tempHash){
#			print "\t\t(", $source, ",", $dest, ",", $sClassAttributeMatrix->{Matrix}->{$source}->{$dest}, ")\n";
#		}
#	}
#	
#
#	print "CM matrix: \n";
#	
#	print "\total sum = ", $sClassMethodMatrix->{myTotalSum}, "\n";
#	foreach my $source (keys %{$sClassMethodMatrix->{Matrix}}){
#		my %tempHash = %{$sClassMethodMatrix->{Matrix}->{$source}};
#		foreach my $dest (keys %tempHash){
#			print "\t\t(", $source, ",", $dest, ",", $sClassMethodMatrix->{Matrix}->{$source}->{$dest}, ")\n";
#		}
#	}
#	
#	
#	print "MM matrix: \n";
#	
#	print "\total sum = ", $sMethodMethodMatrix->{myTotalSum}, "\n";
#	foreach my $source (keys %{$sMethodMethodMatrix->{Matrix}}){
#		my %tempHash = %{$sMethodMethodMatrix->{Matrix}->{$source}};
#		foreach my $dest (keys %tempHash){
#			print "\t\t(", $source, ",", $dest, ",", $sMethodMethodMatrix->{Matrix}->{$source}->{$dest}, ")\n";
#		}
#	}	
	
	my $count = 0;
	
	foreach my $classKey (keys %{$sAllClassNameHash}){
		my $currentClass = $sAllClassNameHash->{$classKey};
		
		$count++;
		print "Computing metrics for class ", $count, "...\n";
		
    my %ancestorClassHash; 
    getAncestorClasses($currentClass, \%ancestorClassHash);	
    
    my %descendentClassHash; 
    getDescendentClasses($currentClass, \%descendentClassHash);  
    
    my %friendClassHash; 
    getFriendClasses($currentClass, \%friendClassHash);  

    my %inverseFriendClassHash; 
    getInverseFriendClasses($currentClass, \%inverseFriendClassHash);	
    
    my %otherClassHash;
    getOtherClasses($currentClass, $sAllClassNameHash, \%ancestorClassHash,\%descendentClassHash, \%friendClassHash, \%inverseFriendClassHash,\%otherClassHash);
    	                             
    my %OthersDiffFriendHash;
	  getDiffHash(\%otherClassHash, \%friendClassHash, \%OthersDiffFriendHash);		                             

		my %OthersDiffInverseFriendHash;
	  getDiffHash(\%otherClassHash, \%friendClassHash, \%OthersDiffInverseFriendHash);		  
	  
	
	  $sBriandCouplingMetrics->{$classKey}->{IFCAIC} = SumOfColumn($currentClass, \%inverseFriendClassHash, $sClassAttributeMatrix);		  
	  $sBriandCouplingMetrics->{$classKey}->{ACAIC} = SumOfColumn($currentClass, \%ancestorClassHash, $sClassAttributeMatrix);	
	  $sBriandCouplingMetrics->{$classKey}->{OCAIC} = SumOfColumn($currentClass, "All", $sClassAttributeMatrix)
	                                                  - SumOfColumn($currentClass, \%OthersDiffFriendHash, $sClassAttributeMatrix);
	                                                  	  
	  
    $sBriandCouplingMetrics->{$classKey}->{FCAEC} = SumOfRow(\%friendClassHash, $currentClass, $sClassAttributeMatrix);
	  $sBriandCouplingMetrics->{$classKey}->{DCAEC} = SumOfRow(\%descendentClassHash, $currentClass, $sClassAttributeMatrix);	
	  $sBriandCouplingMetrics->{$classKey}->{OCAEC} = SumOfRow("All", $currentClass, $sClassAttributeMatrix)
	                                                  - SumOfRow(\%OthersDiffInverseFriendHash, $currentClass, $sClassAttributeMatrix);	
	  
	
	  $sBriandCouplingMetrics->{$classKey}->{IFCMIC} = SumOfColumn($currentClass, \%inverseFriendClassHash, $sClassMethodMatrix);		  
	  $sBriandCouplingMetrics->{$classKey}->{ACMIC} = SumOfColumn($currentClass, \%ancestorClassHash, $sClassMethodMatrix);	
	  $sBriandCouplingMetrics->{$classKey}->{OCMIC} = SumOfColumn($currentClass, "All", $sClassMethodMatrix)
	                                                  - SumOfColumn($currentClass, \%OthersDiffFriendHash, $sClassMethodMatrix);	  

	
	 	$sBriandCouplingMetrics->{$classKey}->{FCMEC} = SumOfRow(\%friendClassHash, $currentClass, $sClassMethodMatrix);
	  $sBriandCouplingMetrics->{$classKey}->{DCMEC} = SumOfRow(\%descendentClassHash, $currentClass, $sClassMethodMatrix);
	  $sBriandCouplingMetrics->{$classKey}->{OCMEC} = SumOfRow("All", $currentClass, $sClassMethodMatrix)
	                                                  - SumOfRow(\%OthersDiffInverseFriendHash, $currentClass, $sClassMethodMatrix);
	
		
	  $sBriandCouplingMetrics->{$classKey}->{IFMMIC} = SumOfColumn($currentClass, \%inverseFriendClassHash, $sMethodMethodMatrix);		  
	  $sBriandCouplingMetrics->{$classKey}->{AMMIC} = SumOfColumn($currentClass, \%ancestorClassHash, $sMethodMethodMatrix);
	  $sBriandCouplingMetrics->{$classKey}->{OMMIC} = SumOfColumn($currentClass, "All", $sMethodMethodMatrix)
	                                                  - SumOfColumn($currentClass, \%OthersDiffFriendHash, $sMethodMethodMatrix);	  
	                                                  	  
	
	  $sBriandCouplingMetrics->{$classKey}->{FMMEC} = SumOfRow(\%friendClassHash, $currentClass, $sMethodMethodMatrix);
	  $sBriandCouplingMetrics->{$classKey}->{DMMEC} = SumOfRow(\%descendentClassHash, $currentClass, $sMethodMethodMatrix);	
	  $sBriandCouplingMetrics->{$classKey}->{OMMEC} = SumOfRow("All", $currentClass, $sMethodMethodMatrix)
	                                                  - SumOfRow(\%OthersDiffInverseFriendHash, $currentClass, $sMethodMethodMatrix);

   my %descendentClassHash;
   getDescendentClasses($currentClass, \%descendentClassHash);	                                                   
	 $sBriandCouplingMetrics->{totalNOD} += NOD($currentClass, \%descendentClassHash);  #为DOR的计算做准备                                                 
	                                                   
	}#END for
	
	return 1;	
}#END sub BriandCouplingSeries


sub SumOfColumn{
	#给定一个矩阵A[i, j], 计算j = 1..n 时 A[i, j]的累加和, 即行坐标不变, 列变化时的和
	my $sRowClass = shift;
	my $sColumnClassHash = shift;
	my $sMatrixHash = shift;
	
	my $result = 0;	
	my $rowClassKey = getClassKey($sRowClass); 
	
	my $actualColumnHash;
	
	if ($sColumnClassHash =~ m/All/i){
		$actualColumnHash = $sMatrixHash->{Matrix}->{$rowClassKey};
	}
	else{
		$actualColumnHash = $sColumnClassHash;
	}
		
	foreach my $columnClassKey (keys %{$actualColumnHash}){				
		next if (!exists $sMatrixHash->{Matrix}->{$rowClassKey});
		next if (!exists $sMatrixHash->{Matrix}->{$rowClassKey}->{$columnClassKey});
		
		$result = $result + $sMatrixHash->{Matrix}->{$rowClassKey}->{$columnClassKey};
	}
		
	return $result;	
}#END sub SumOfColumn



sub SumOfRow{
	#给定一个矩阵A[i, j], 计算i = 1..n 时 A[i, j]的累加和, 即列坐标不变, 行变化时的和
	my $sRowClassHash = shift;
	my $sColumnClass = shift;
	my $sMatrixHash = shift;
	
	my $result = 0;
	my $columnClassKey = getClassKey($sColumnClass); 
	
	my $actualRowHash;
	
	if ($sRowClassHash =~ m/All/i){
		$actualRowHash = $sMatrixHash->{Matrix};
	}
	else{
		$actualRowHash = $sRowClassHash;
	}	
		
	foreach my $rowClassKey (keys %{$actualRowHash}){		
		next if (!exists $sMatrixHash->{Matrix}->{$rowClassKey});
		next if (!exists $sMatrixHash->{Matrix}->{$rowClassKey}->{$columnClassKey});
		
		$result = $result + $sMatrixHash->{Matrix}->{$rowClassKey}->{$columnClassKey};
	}
		
	return $result;	
}#END sub SumOfColumn


sub getUnionHash{
	my $firstHash = shift;
	my $secondHash = shift;
	my $unionHash = shift;
	
	foreach my $key (%{$firstHash}){
		$unionHash->{$key} = $firstHash->{$key};
	}
	
	foreach my $key (%{$secondHash}){
		$unionHash->{$key} = $secondHash->{$key};
	}
	
	return 1;
}


#$diffHash = $firstHash - $secondHash
sub getDiffHash{
	my $firstHash = shift;
	my $secondHash = shift;
	my $diffHash = shift;
	
	foreach my $key (%{$firstHash}){
		$diffHash->{$key} = $firstHash->{$key};
	}
	
	foreach my $key (%{$secondHash}){
		delete $diffHash->{$key} if (exists $diffHash->{$key});		
	}	
	
	return 1;
}


sub IFCAIC{
	my $sClass = shift;	
	my $sInverseFriendClassHash = shift;
	my $sClassAttributeMatrix = shift;
	
	print "\t\t\t computing IFCAIC..." if ($debug);
	
	my $result = 0;	
  
  foreach my $key (keys %{$sInverseFriendClassHash}){
  	my $inverseFriend = $sInverseFriendClassHash->{$key};  	  
    $result = $result + getNoOfClassAttributeInteraction($sClass, $inverseFriend);
  }

	print "...IFCAIC END\n" if ($debug);
	  
	return $result;
}#END sub IFCAIC


sub ACAIC{
	my $sClass = shift;
	my $sAncestorClassHash = shift;
	
	print "\t\t\t computing ACAIC..." if ($debug);
	
	my $result = 0;	
  
  foreach my $key (keys %{$sAncestorClassHash}){
  	my $ancestor = $sAncestorClassHash->{$key};  	  
    $result = $result + getNoOfClassAttributeInteraction($sClass, $ancestor);
  }
  
  print "... ACAIC END\n" if ($debug);
  
	return $result;
}#END sub ACAIC



sub OCAIC{
	my $sClass = shift;
	my $sFriendClassHash = shift;
	my $sOtherClassHash = shift;
	
	print "\t\t\t computing OCAIC..." if ($debug);
	
	my $result = 0;	
  
  foreach my $key (keys %{$sOtherClassHash}){
  	my $other = $sOtherClassHash->{$key};  	  
    $result = $result + getNoOfClassAttributeInteraction($sClass, $other);
  }
 
  foreach my $key (keys %{$sFriendClassHash}){
  	my $friend = $sFriendClassHash->{$key};  	  
    $result = $result + getNoOfClassAttributeInteraction($sClass, $friend);
  }
  
  print "...OCAIC END\n" if ($debug);
	return $result;
}#END sub OCAIC



sub FCAEC{
	my $sClass = shift;
	my $sFriendClassHash = shift;
#	print "\t\t\t computing FCAEC...\n";
	
	my $result = 0;	
  
  foreach my $key (keys %{$sFriendClassHash}){
  	my $friend = $sFriendClassHash->{$key};  	  
    $result = $result + getNoOfClassAttributeInteraction($friend, $sClass);
  }
  
	return $result;
}#END sub FCAEC



sub DCAEC{
	my $sClass = shift;
	my $sDescendentClassHash = shift;
	
	print "\t\t\t computing DCAEC..." if ($debug);
	
	my $result = 0;	
  
  foreach my $key (keys %{$sDescendentClassHash}){
  	my $descendent = $sDescendentClassHash->{$key};  	  
    $result = $result + getNoOfClassAttributeInteraction($descendent, $sClass);
  }
  
  print "...DCAEC END\n" if ($debug);
  
	return $result;
}#END sub DCAEC



sub OCAEC{	
	my $sClass = shift;
	my $sInverseFriendClassHash = shift;
	my $sOtherClassHash = shift;
	
	print "\t\t\t computing OCAEC..." if ($debug);
	
	my $result = 0;	
 
  foreach my $key (keys %{$sOtherClassHash}){
  	my $other = $sOtherClassHash->{$key};  	  
    $result = $result + getNoOfClassAttributeInteraction($other, $sClass);
  }
  
  foreach my $key (keys %{$sInverseFriendClassHash}){
  	my $inverseFriend = $sInverseFriendClassHash->{$key};  	  
    $result = $result + getNoOfClassAttributeInteraction($inverseFriend, $sClass);
  }
  
  print "...OCAEC END\n" if ($debug);
  
	return $result;
}#END sub OCAEC



sub IFCMIC{
	my $sClass = shift;
	my $sInverseFriendClassHash = shift;
	
#	print "\t\t\t computing IFCMIC...\n";
	
	my $result = 0;	
  
  foreach my $key (keys %{$sInverseFriendClassHash}){
  	my $inverseFriend = $sInverseFriendClassHash->{$key};  	  
    $result = $result + getNoOfClassMethodInteraction($sClass, $inverseFriend);
  }
  
	return $result;
}#END sub IFCMIC




sub ACMIC{
	my $sClass = shift;
	my $sAncestorClassHash = shift;
	print "\t\t\t computing ACMIC..." if ($debug);
	
	my $result = 0;	
  
  foreach my $key (keys %{$sAncestorClassHash}){
  	my $ancestor = $sAncestorClassHash->{$key};  	  
    $result = $result + getNoOfClassMethodInteraction($sClass, $ancestor);
  }
  
  print "...ACMIC END\n" if ($debug);
	return $result;
}#END sub ACMIC



sub OCMIC{
	my $sClass = shift;
	my $sFriendClassHash = shift;
	my $sOtherClassHash = shift;	
	
	print "\t\t\t computing OCMIC..." if ($debug);
	
	my $result = 0;	
  
  foreach my $key (keys %{$sOtherClassHash}){
  	my $other = $sOtherClassHash->{$key};  	  
    $result = $result + getNoOfClassMethodInteraction($sClass, $other);
  }  
  
  foreach my $key (keys %{$sFriendClassHash}){
  	my $friend = $sFriendClassHash->{$key};  	  
    $result = $result + getNoOfClassMethodInteraction($sClass, $friend);
  }
  
  print "...OCMIC END\n" if ($debug);
	return $result;
}#END sub OCMIC



sub FCMEC{
	my $sClass = shift;
	my $sFriendClassHash = shift;
#	print "\t\t\t computing FCMEC...\n";
	
	my $result = 0;	
  
  foreach my $key (keys %{$sFriendClassHash}){
  	my $friend = $sFriendClassHash->{$key};  	  
    $result = $result + getNoOfClassMethodInteraction($friend, $sClass);
  }
  
	return $result;
}#END sub FCMEC


sub DCMEC{
	my $sClass = shift;
	my $sDescendentClassHash = shift;
	
	print "\t\t\t computing DCMEC..." if ($debug);
	
	my $result = 0;
	
  foreach my $key (keys %{$sDescendentClassHash}){
  	my $descendent = $sDescendentClassHash->{$key};  	  
    $result = $result + getNoOfClassMethodInteraction($descendent, $sClass);
  }
  
  print "...DCMEC END\n" if ($debug);
	return $result;
}#END sub DCMEC



sub OCMEC{
	my $sClass = shift;
	my $sInverseFriendClassHash = shift;
	my $sOtherClassHash = shift;
	
	print "\t\t\t computing OCMEC..." if ($debug);
	
	my $result = 0;	
  
  foreach my $key (keys %{$sOtherClassHash}){
  	my $other = $sOtherClassHash->{$key};  	  
    $result = $result + getNoOfClassMethodInteraction($other, $sClass);
  }
  
  foreach my $key (keys %{$sInverseFriendClassHash}){
  	my $inverseFriend = $sInverseFriendClassHash->{$key};  	  
    $result = $result + 
    ($inverseFriend, $sClass);
  }
  
  print "...OCMEC END\n" if ($debug);
  
	return $result;
}#END sub OCMEC



sub IFMMIC{
	my $sClass = shift;
	my $sInverseFriendClassHash = shift;
	
#	print "\t\t\t computing IFMMIC...\n";
	
	my $result = 0;
	
  foreach my $key (keys %{$sInverseFriendClassHash}){
  	my $inverseFriend = $sInverseFriendClassHash->{$key};  	  
    $result = $result + getNoOfMethodMethodInteraction($sClass, $inverseFriend);
  }
  
	return $result;
}#END sub IFMMIC


sub AMMIC{
	my $sClass = shift;
	my $sAncestorClassHash = shift;
	
	print "\t\t\t computing AMMIC..." if ($debug);
	
	my $result = 0;
  
  foreach my $key (keys %{$sAncestorClassHash}){
  	my $ancestor = $sAncestorClassHash->{$key};  	  
    $result = $result + getNoOfMethodMethodInteraction($sClass, $ancestor);
  }
  
  print "...AMMIC END\n" if ($debug);
  
	return $result;
}#END sub AMMIC


sub OMMIC{	
	my $sClass = shift;
  my $sFriendClassHash = shift;
  my $sOtherClassHash	= shift;
	
	print "\t\t\t computing OMMIC..." if ($debug);
	
	my $result = 0;
 
  foreach my $key (keys %{$sOtherClassHash}){
  	my $other = $sOtherClassHash->{$key};  	  
    $result = $result + getNoOfMethodMethodInteraction($sClass, $other);
  }
  
  foreach my $key (keys %{$sFriendClassHash}){
  	my $friend = $sFriendClassHash->{$key};  	  
    $result = $result + getNoOfMethodMethodInteraction($sClass, $friend);
  }
  
  print "...OMMIC END\n" if ($debug);
  
	return $result;
}#END sub OMMIC


sub FMMEC{
	my $sClass = shift;
	my $sFriendClassHash = shift;
	
#	print "\t\t\t computing FMMEC...\n";
	
	my $result = 0;
	
  foreach my $key (keys %{$sFriendClassHash}){
  	my $friend = $sFriendClassHash->{$key};  	  
    $result = $result + getNoOfMethodMethodInteraction($friend, $sClass);
  }
  
	return $result;
}#END sub FMMEC



sub DMMEC{
	my $sClass = shift;
	my $sDescendentClassHash = shift;
	
	print "\t\t\t computing DMMEC..." if ($debug);
	
	my $result = 0;	
  
  foreach my $key (keys %{$sDescendentClassHash}){
  	my $descendent = $sDescendentClassHash->{$key};  	  
    $result = $result + getNoOfMethodMethodInteraction($descendent, $sClass);
  }
  
  print "...DMMEC END\n" if ($debug);
  
	return $result;
}#END sub DMMEC


sub OMMEC{
	my $sClass = shift;
	my $sInverseFriendClassHash = shift;
	my $sOtherClassHash = shift;	
	
	print "\t\t\t computing OMMEC..." if ($debug);
	
	my $result = 0;
	
  foreach my $key (keys %{$sOtherClassHash}){
  	my $other = $sOtherClassHash->{$key};  	  
    $result = $result + getNoOfMethodMethodInteraction($other, $sClass);
  }
  
  foreach my $key (keys %{$sInverseFriendClassHash}){
  	my $inverseFriend = $sInverseFriendClassHash->{$key};  	  
    $result = $result + getNoOfMethodMethodInteraction($inverseFriend, $sClass);
  }
  
  print "...OMMEC END\n" if ($debug);
  
	return $result;
}#END sub OMMEC


sub CBI{
	my $sClass = shift;
	my $sDescendentHash = shift;
	
	print "\t\t\t computing CBI..." if ($debug);
	
	my $sumIMC = 0;
	
	my @methodArray = getEntsInClass($sClass, "define", "function ~unresolved ~unknown, method ~unresolved ~unknown");
	
	foreach my $func (@methodArray){
		$sumIMC = $sumIMC + IMC($func);
	}
	
	my $result = $sumIMC * NOD($sClass, $sDescendentHash);
	
	print "...CBI END\n" if ($debug);
	
	return $result;	
}#END sub CBI


sub CCAndAMC{
	my $sClass = shift;
	
	print "\t\t\t computing CC and AMC..." if ($debug);
	
	my $valueCC = 0;	
	
	my $currentClassName = getLastName($sClass->name());	
	
	my @methodArray = getEntsInClass($sClass, "Define","Function ~Unknown ~Unresolved, Method ~Unknown ~Unresolved");	
	
	return (0, 0) if (@methodArray == 0);
	
	foreach my $func (@methodArray){
#		print "\t func = ", $func->name(), "\n";
	
		#分析方法中引用的非局部变量
		my @localVariableList = $func->refs("Use, Set, Modify", "Object ~unknown ~unresolved ~Local, Variable ~unknown ~unresolved ~Local");

		foreach my $variable (@localVariableList){	
			my $variableDefineInEnt = $variable->ent()->ref("Definein", "");		
		  if (!$variableDefineInEnt){  #全局变量
		  	$valueCC++;
		  	next;		  	
		  }	
		  
		  next if ($variableDefineInEnt->ent()->library() =~ m/Standard/i);
		  
		  my $variableDefineInEntName = getLastName($variableDefineInEnt->ent()->name);		  		  
		  
		  next if ($variableDefineInEntName eq $currentClassName); 		  

#		  print "\t\t\t non local variable = ", $variable->ent()->name(), "\n";
#		  print "\t\t\t type = ", $variableDefineInEntName, "\n";
#		  print "\t\t\t current = ", $currentClassName, "\n";
		  
		  $valueCC++;
		}
		
		
		#分析方法中调用的方法
		my @calledFuncSet = $func->refs("call", "function ~unresolved ~unknown, method ~unresolved ~unknown");
  	foreach my $calledfunc (@calledFuncSet){
  		my $calledFuncDefineInEnt = $calledfunc->ent()->ref("Definein", "");
  		if (!$calledFuncDefineInEnt){
  			$valueCC++;
  			next;  			
  		}  		 
  		
  		next if ($calledFuncDefineInEnt->ent()->library() =~ m/Standard/i);
  		
  		my $calledFuncDefineInEntName = getLastName($calledFuncDefineInEnt->ent()->name());		
  		next if ($calledFuncDefineInEntName eq $currentClassName); 
  		

#		  print "\t\t\t non local method = ", $calledfunc->ent()->name(), "\n";
#		  print "\t\t\t type = ", $calledFuncDefineInEntName, "\n";
#		  print "\t\t\t current = ", $currentClassName, "\n";  		
  		
  		$valueCC++;  		
	  }
	}
	
	my $valueAMC = $valueCC / @methodArray;
	
	print "...CCAndAMC END\n" if ($debug);
	
	return ($valueCC, $valueAMC);	
}#END sub CCAndAMC



sub UCL{
	my $sClass = shift;
	my $sAllClassNameHash = shift;
	my $sAncestorHash = shift;
	my $sDescendentHash = shift;
	
	my $currentClassKey = getClassKey($sClass);
	
	print "\t\t\t computing UCL..." if ($debug);
	
	my %ancestorHash = %{$sAncestorHash};
	my %descendentHash = %{$sDescendentHash};	#之所以用Hash表, 考虑多继承的情况

	my $miu13 = 0;
	
	#计算以其他类(非祖先类, 非子孙类)为类型的属性的数目
	my @attributeArray = getRefsInClass($sClass, "Define","Member Object ~unknown ~unresolved, Member Variable ~unknown ~unresovled");	
  
	foreach my $attribute (@attributeArray){
		my $attributeClass = $attribute->ent()->ref("Typed", "Class");		
		next if (!$attributeClass);		
		next if ($attributeClass->ent()->library() =~ m/Standard/i);
		
		#去掉标准的类, 只统计应用类
		my $attributeClassKey = getClassKey($attributeClass->ent());
		#next if (!exists $sAllClassNameHash->{$attributeClassKey});
		
		next if ($currentClassKey eq $attributeClassKey); 		
 	  next if (exists $ancestorHash{$attributeClassKey});
		next if (exists $descendentHash{$attributeClassKey});
		
		$miu13++; 
	}
	
	
	#计算方法中以其他类(非祖先类, 非子孙类)为类型的局部变量(包括参数和返回值)的数目
	my @methodArray = getEntsInClass($sClass, "Define","Function ~Unknown ~Unresolved, Method ~Unknown ~Unresolved");	
	my $miu24 = 0;
	
	foreach my $func (@methodArray){
#		print "\t func = ", $func->name(), "\n";
		#分析参数类型
		my @parameterList = $func->ents("Define", "Parameter");
		
		foreach my $parameter (@parameterList){
			my $parameterClass = $parameter->ref("Typed", "Class");
			next if (!$parameterClass);		
			next if ($parameterClass->ent()->library() =~ m/Standard/i);

  		#去掉标准的类, 只统计应用类
		  my $parameterClassKey = getClassKey($parameterClass->ent());		
		  #next if (!exists $sAllClassNameHash->{$parameterClassKey});
		  
		  next if ($currentClassKey eq $parameterClassKey); 
		  next if (exists $ancestorHash{$parameterClassKey});
		  next if (exists $descendentHash{$parameterClassKey});
		  
		  $miu24++;
		}
		
	
		#分析方法中定义的局部变量
		my @localVariableList = $func->refs("define", "Object ~Unknown ~Unresolved, Variable ~Unknown ~Unresolved");
		foreach my $variable (@localVariableList){	
			my $variableClass = $variable->ent()->ref("Typed", "Class");		
		  next if (!$variableClass);		
		  next if ($variableClass->ent()->library() =~ m/Standard/i);
		  
		  #去掉标准的类, 只统计应用类		  
		  my $variableClassKey = getClassKey($variableClass->ent());		
		  #next if (!exists $sAllClassNameHash->{$variableClassKey});
		  
		  next if ($currentClassKey eq $variableClassKey); 
		  next if (exists $ancestorHash{$variableClassKey});
		  next if (exists $descendentHash{$variableClassKey});				  
		  
		  $miu24++;
		}
		
		
		#分析返回类型
		my $returnClass = $func->ref("Typed", "Class");
	  next if (!$returnClass);
	  next if ($returnClass->ent()->library() =~ m/Standard/i);
		
	  #去掉标准的类, 只统计应用类
    my $returnClassKey = getClassKey($returnClass->ent());		
    #next if (!exists $sAllClassNameHash->{$returnClassKey});
    
    next if ($currentClassKey eq $returnClassKey); 
		next if (exists $ancestorHash{returnClassKey});
		next if (exists $descendentHash{returnClassKey});				
		
		$miu24++;  
	}
	
	
	my $result = $miu13 + $miu24;
	
	print "...UCL END\n" if ($debug);
	
	return $result;
}#END sub UCL


sub ICH{
	my $sClass = shift;
	
	print "\t\t\t computing ICH..." if ($debug);

	my @methodArray = getEntsInClass($sClass, "define","function ~unknown ~unresovled, method ~unknown ~unresovled");    
	
	my $result = 0;
  
  my $callingClassKey = getClassKey($sClass);


  #只考虑动态的调用    
  foreach my $method (@methodArray){
  	my $callingMethodName = getLastName($method->name());
  	my %polyCalledFuncSet;
  	PIM($method, \%polyCalledFuncSet);
  	
#  	print "\t\t calling method = ", $method->name(), "\n";
  	
  	foreach my $key (sort keys %polyCalledFuncSet){
  		my $calledFuncEnt = $polyCalledFuncSet{$key}->{funcEnt};
  		my $callCount = $polyCalledFuncSet{$key}->{callCount};
  		
  		my $calledClass = $calledFuncEnt->ref("Definein", "Class");
  		next if (!$calledClass);
  		
  		my $calledClassKey = getClassKey($calledClass->ent());  		
  		next if ($callingClassKey ne $calledClassKey);

  		#排除调用自身
  		my $calledMethodName = getLastName($calledFuncEnt->name());
  		next if ($callingMethodName eq $calledMethodName);  		
  		
  		my @parameterSet = $calledFuncEnt->ents("Define", "Parameter");
  		
#  		print "\t\t\t called method = ", $key, "\n";
#  		print "\t\t\t count = ", $callCount, "\n";
  		$result = $result + (@parameterSet + 1) * $callCount;  
  	}
  }



#  #只考虑静态的调用 
#  foreach my $method (@methodArray){
#  	my $callingMethodName = getLastName($method->name());
#  	my @calledFuncSet = $method->refs("call", "function  ~unresolved ~unknown, method  ~unresolved ~unknown");
#  	foreach my $func (@calledFuncSet){
#  		my $calledClass = $func->ent()->ref("Definein", "Class ~unknown ~unresovled");
#  		next if (!$calledClass);
#  		
#  		my $calledClassKey = getClassKey($calledClass->ent());  		
#  		next if ($callingClassKey ne $calledClassKey); 
#  		
#  		#排除调用自身
#  		my $calledMethodName = getLastName($func->ent()->name());
#  		next if ($callingMethodName eq $calledMethodName);
#  		
#  		my @parameterSet = $func->ent()->ents("Define", "Parameter");
#  		$result = $result + @parameterSet + 1;  		
#  	}
#  }
  
  print "...ICH END\n" if ($debug);
  
  return $result;		
}#END sub ICH


sub SPoly{
	my $firstClass = shift;
	my $secondClass = shift;
	
	my %firstFuncHash;
	
	my @firstFuncList = getEntsInClass($firstClass, "Define", "Function ~private, Method ~private");
	foreach my $func (@firstFuncList){
		my $signature = getFuncSignature($func, 0);		
		my $realFuncName = getLastName($func->name());				
		$firstFuncHash{$realFuncName}{$signature} = 1;
	}
	
	my %secondFuncHash;
	
	my @secondFuncList = getEntsInClass($secondClass, "Define", "Function ~private, Method ~private");
	foreach my $func (@secondFuncList){
		my $signature = getFuncSignature($func, 0);
		
		my $realFuncName = getLastName($func->name());	

		$secondFuncHash{$realFuncName} = 1 if (exists $firstFuncHash{$realFuncName} && !exists $firstFuncHash{$realFuncName}{$signature});
	}

	my $result = 0;
	$result = (keys %secondFuncHash);

	return $result;
}#END sub SPoly



sub SPA{
	my $sClass = shift;
	my $sAncestorHash = shift;
	
#	print "\t\t\t computing SPA...\n";
	
	my %ancestorHash = %{$sAncestorHash};
  
	my $result = 0;
	foreach my $key (keys %ancestorHash){
		my $ancestorClass = $ancestorHash{$key};
		$result = $result + SPoly($ancestorClass, $sClass);
	}
	
	return $result;	
}#END sub SPA


sub SPD{
	my $sClass = shift;	
	my $sDescendentHash = shift;
	
#	print "\t\t\t computing SPD...\n";
	
	my %descendentHash = %{$sDescendentHash};	#之所以用Hash表, 考虑多继承的情况
	
	my $result = 0;
	foreach my $key (keys %descendentHash){
		my $descendentClass = $descendentHash{$key};
		$result = $result + SPoly($descendentClass, $sClass);		
	}
	
	return $result;	
}#END sub SPD


sub DPoly{
	my $firstClass = shift;
	my $secondClass = shift;

	my %firstFuncHash;
	
	my @firstFuncList = getEntsInClass($firstClass, "Define", "Function ~private, Method ~private");
	foreach my $func (@firstFuncList){
		my $signature = getFuncSignature($func, 1);			
		$firstFuncHash{$signature} = 1;
	}
	
	my %secondFuncHash;
	
	my @secondFuncList = getEntsInClass($secondClass, "Define", "Function ~private, Method ~private");
	foreach my $func (@secondFuncList){
		my $signature = getFuncSignature($func, 1);
		$secondFuncHash{$signature} = 1 if (exists $firstFuncHash{$signature});
	}
		
	my $result = 0;
	$result = (keys %secondFuncHash);
	
	return $result;
}#END sub DPoly


sub DPA{
	my $sClass = shift;
	my $sAncestorHash = shift;
	
#	print "\t\t\t computing DPA...\n";
	
	my %ancestorHash = %{$sAncestorHash};
	
	my $result = 0;
	foreach my $key (keys %ancestorHash){
		my $ancestorClass = $ancestorHash{$key};
		$result = $result + DPoly($ancestorClass, $sClass);
	}
	
	return $result;	
}#END sub DPA


sub DPD{
	my $sClass = shift;
	my $sDescendentHash = shift;
	
#	print "\t\t\t computing DPD...\n";
	
	my %descendentHash = %{$sDescendentHash};	#之所以用Hash表, 考虑多继承的情况
	
	my $result = 0;
	foreach my $key (keys %descendentHash){
		my $descendentClass = $descendentHash{$key};
		$result = $result + DPoly($descendentClass, $sClass);
	}
	
	return $result;	
}#END sub DPD


sub SP{
	my $sSPA = shift;
	my $sSPD = shift;	
	
	my $result = 0;
	$result = $sSPA + $sSPD;	
	
	return $result;
}#END sub SP


sub DP{
	my $sDPA = shift;
	my $sDPD = shift;
	
	my $result = 0;
	$result = $sDPA + $sDPD;		

	return $result;
}#END sub DP

sub CHM{
	my $sDIT = shift;
	my $sNOD = shift;
	my $sNOP = shift;
	my $sNMI = shift;
	my $sNMA = shift;
	
	my $result = 0;
	$result = $sDIT + $sNOD + $sNOP + $sNMI + $sNMA;
	
	return $result;	
}#END sub CHM


sub DOR{
	my $sClass = shift;
	my $sAllClassNameHash = shift;
	my $sDescendentHash = shift;
	my $sTrTr = shift;
	
  my $tt = scalar (keys %{$sAllClassNameHash});
  my $trtr = $sTrTr;
	
	my $rc;
	$rc = NOD($sClass, $sDescendentHash);
	
	my $result = 0;
	
	for (my $k = 1; $k <= $rc; $k++){
		$result = $result + $k/($tt + $trtr);
	}
	
	return $result;	
}#END sub DOR



sub OVO{
	my $sClass = shift;
	
	my @currentFuncList = getEntsInClass($sClass, "Define", "Function ~private, Method ~private");
	
	my %funcHash;
	
	foreach my $func (@currentFuncList){
		$funcHash{$func->name()}++;		
	}
	
	my $result = 0;
	
	foreach my $key (keys %funcHash){
		$result = $result + $funcHash{$key} if $funcHash{$key} > 1;
	}
	
	return $result;	
}


sub NM{
	my $sClass = shift;
	my $sAncestorHash = shift;
	
	print "\t\t\t computing NM..." if ($debug);
	
	my %ancestorHash = %{$sAncestorHash};
	
	my %methodInAncestor; # 祖先类中的方法集
	
	foreach my $key (keys %ancestorHash){
		my $ancestorClass = $ancestorHash{$key};
		
		my @funcList = getEntsInClass($ancestorClass, "Define", "Function ~private, Method ~private");
		
		foreach my $func (@funcList){
			my $signature = getFuncSignature($func, 1);
			$methodInAncestor{$signature} = 1;
		}
	}
	
	my $count = 0;
	
	my @currentFuncList = getEntsInClass($sClass, "Define", "Function, Method");
	
	foreach my $func (@currentFuncList){
		my $currentSignature = getFuncSignature($func, 1);
		if (exists $methodInAncestor{$currentSignature}){
			$count++;
#			print "count = ", $count, " method = ", $currentSignature, "\n";
		};		
	}
	
#	print "methodInAncestor = ", scalar (keys %methodInAncestor), "\n";
#	print "currentFuncList = ", scalar @currentFuncList, "\n";	
#	print "count = ", $count, "\n";
	
	my $result = 0;

	$result = (keys %methodInAncestor) + @currentFuncList - $count;

	
	print "...NM END\n" if ($debug);
		
	return $result;
}#END sub NM


sub NA{
	my $sClass = shift;
	my $sAncestorHash = shift;
	
	print "\t\t\t computing NA..." if ($debug);
	
	my %ancestorHash = %{$sAncestorHash};
	
	my $result = $sClass->metric("CountDeclClassVariable") + $sClass->metric("CountDeclInstanceVariable");;
	
	
	foreach my $key (keys %ancestorHash){
		my $ancestorClass = $ancestorHash{$key};	
		my @attributeArray = getEntsInClass($ancestorClass, "define", "member object ~unknown ~unresolved, Member Variable ~unknown ~unresolved");      
		$result = $result + scalar @attributeArray;		
	}
	
	return $result;
}#END sub NA


sub Nmpub{
	my $sClass = shift;

	my @currentFuncList = getEntsInClass($sClass, "Define", "Function ~private ~protected ~unresolved, Method ~private ~protected  ~unresolved");	
	my $result = 0;
	$result = @currentFuncList;
	
	return $result;	
}#END sub Nmpub



sub NMNpub{
	my $sClass = shift;

	my @currentFuncList = getEntsInClass($sClass, "Define", "Function ~unresolved, Method ~unresolved");	
	my $result = 0;
	$result = @currentFuncList - Nmpub($sClass);
	
	return $result;	
}#END sub NMNpub



sub NumPara{
	my $sClass = shift;
	
	my @currentFuncList = getEntsInClass($sClass, "Define", "Function ~unresolved, Method ~unresolved");	
	
	my $result = 0;
	
	foreach my $func (@currentFuncList){
		my @parameterList = $func->ents("Define", "Parameter");
		$result = $result + @parameterList;
	}
	
	return $result;	
}#END sub NumPara



sub InheritanceSeries{
	my $sClass = shift;
	my $sAllClassNameHash = shift;
	my $sAncestorHash = shift;
	my $sAncestorLevel = shift;
	my $sDescendentClassHash = shift;
	my $sHashMetrics = shift;
	
	my $valueNOC = NOC($sClass);
	$sHashMetrics->{Inheritance}->{NOC} = $valueNOC;
	
	my $valueNOP = NOP($sClass);
	$sHashMetrics->{Inheritance}->{NOP} = $valueNOP;
	
	my $valueDIT = DIT($sClass);
	$sHashMetrics->{Inheritance}->{DIT} = $valueDIT;
	
	my $valueAID = AID($sClass);
	$sHashMetrics->{Inheritance}->{AID} = $valueAID;
	
	my $valueCLD = CLD($sClass);
	$sHashMetrics->{Inheritance}->{CLD} = $valueCLD;
	
	# my $start = getTimeInSecond();
	my $valueNOD = NOD($sClass, $sDescendentClassHash);
	$sHashMetrics->{Inheritance}->{NOD} = $valueNOD;
	# reportComputeTime($start, "NOD");  
	
	# $start = getTimeInSecond();
	my $valueNOA = NOA($sClass, $sAncestorHash);
	$sHashMetrics->{Inheritance}->{NOA} = $valueNOA;
	# reportComputeTime($start, "NOA");  
	
	# $start = getTimeInSecond();
	my $valueNMO = NMO($sClass, $sAncestorHash);
	$sHashMetrics->{Inheritance}->{NMO} = $valueNMO;
	# reportComputeTime($start, "NMO");  
	
	# $start = getTimeInSecond();
	my $valueNMI = NMI($sClass, $sAncestorHash);
	$sHashMetrics->{Inheritance}->{NMI} = $valueNMI;
	# reportComputeTime($start, "NMI"); 	
	
	# $start = getTimeInSecond();
	my $valueNMA = NMA($sClass);
	$sHashMetrics->{Inheritance}->{NMA} = $valueNMA;
	# reportComputeTime($start, "NMA"); 
	
	
	my $valueSIX = SIX($valueNMO, $valueNMA, $valueNMI, $valueDIT);
	$sHashMetrics->{Inheritance}->{SIX} = $valueSIX;
	
	
	# $start = getTimeInSecond();
	my $valueNPBM = getNoOfPBRdM($sClass, $sAncestorHash, $sAncestorLevel); #得到保留行为的override方法数目  Preserved Behavior OverRide Method
	my $valuePII = PII($valueNPBM, $valueNMO, $valueNMA, $valueNMI, $valueDIT);
	$sHashMetrics->{Inheritance}->{PII} = $valuePII;
	# reportComputeTime($start, "PII"); 
	
	# $start = getTimeInSecond();
	my $valueSPA = SPA($sClass, $sAncestorHash);
	$sHashMetrics->{Inheritance}->{SPA} = $valueSPA;
	# reportComputeTime($start, "SPA"); 


  # $start = getTimeInSecond();
	my $valueSPD = SPD($sClass, $sDescendentClassHash);
	$sHashMetrics->{Inheritance}->{SPD} = $valueSPD;
	# reportComputeTime($start, "SPD"); 
	
	# $start = getTimeInSecond();
	my $valueDPA = DPA($sClass, $sAncestorHash);
	$sHashMetrics->{Inheritance}->{DPA} = $valueDPA;
	# reportComputeTime($start, "DPA"); 
	
	# $start = getTimeInSecond();
	my $valueDPD = DPD($sClass, $sDescendentClassHash);
	$sHashMetrics->{Inheritance}->{DPD} = $valueDPD;
	# reportComputeTime($start, "DPD"); 
	
	my $valueSP = SP($valueSPA, $valueSPD);
	$sHashMetrics->{Inheritance}->{SP} = $valueSP;
	
	my $valueDP = DP($valueDPA, $valueDPD);
	$sHashMetrics->{Inheritance}->{DP} = $valueDP;
	
	
#	my $valueCHM = CHM($valueDIT, $valueNOD, $valueNOP, $valueNMI, $valueNMA);
#	$sHashMetrics->{Inheritance}->{CHM} = $valueCHM;	
}#END sub InheritanceSeries


sub NOC{
	my $sClass = shift;
	
	#my $result = $sClass->metric("CountClassDerived");
	my @sonList = $sClass->refs("Derive, Extendby", "class", 1); #如果不加1, 在分析Java程序有时出错,原因未知
	
	my $result = @sonList;	
	
	return $result;	
}#END sub NOC


sub NOP{
	my $sClass = shift;	
	
	my @parentList = $sClass->refs("Base, Extend", "class", 1); #如果不加1, 在分析Java程序有时出错,原因未知
	
	my $result = @parentList;	
#	$result = $sClass->metric("CountClassBase");  #对于Java, 计算结果中包括了实现的接口, 所以采用自定义的计算
	
	return $result;
}#END sub NOP
	

sub DIT{
	my $sClass = shift;
	#在Java中, 任何类都是Object的后裔类, 但我们只考虑应用类的继承层次
	
#	return $sClass->metric("MaxInheritanceTree");

	my @parentList;
	
	foreach my $parent ($sClass->refs("Base, Extend", "class", 1)){
		push @parentList, $parent->ent();		
	}	
	
	return 0 if (!@parentList);
	
	my $result = 0;
	
	foreach my $parent (@parentList){
		my $tempDIT = DIT($parent);
		$result = $tempDIT if ($result < $tempDIT);
	}
	
	$result = $result + 1;	
	
  return $result;
} #END sub DIT


sub AID{
	my $sClass = shift;	
	
#	print "\t\t\t computing AID...";

	my @parentList;
	
	foreach my $parent ($sClass->refs("Base, Extend", "class", 1)){
		push @parentList, $parent->ent();		
	}	
	
	return 0 if (!@parentList);

	my $result = 0;
	
	foreach my $parent (@parentList){
		$result = $result + AID($parent);
	}
	
	$result = $result / (scalar @parentList) + 1;
	
#	print "...AID END\n";
	
	return $result;	
}#END sub AID


sub CLD{
	my $sClass = shift;	

#  print "\t\t\t computing CLD...";

	my @sonList;
	
	foreach my $son ($sClass->refs("Derive, Extendby", "class", 1)){
		push @sonList, $son->ent();		
	}	
	
	return 0 if (!@sonList);
	
	my $result = 0;
	
	foreach my $son (@sonList){
		$result = CLD($son) if ($result < CLD($son));
	}
		
	$result = $result + 1;
	
#	print "...CLD END\n";
	
	return $result;	
}#END sub CLD



sub NOD{
	my $sClass = shift;	
	my $sDescendentHash = shift;
	
	my %descendentHash = %{$sDescendentHash};	#之所以用Hash表, 考虑多继承的情况
	
	my $result = 0;
	$result = (keys %descendentHash); 
	return $result;
}#END sub NOD


sub NOA{
	my $sClass = shift;	
	my $sAncestorHash = shift;
	
	my %ancestorHash = %{$sAncestorHash};	#之所以用Hash表, 考虑多继承的情况
	
	my $result = 0;
	$result = (keys %ancestorHash);
	
	return $result;	
}#END sub NOA


sub getFuncSignature{
	my $func = shift;
	my $includeReturnType = shift; 
	
	my $signature;
  my @wordList = split /\./, $func->name();
  
  if ($includeReturnType){
	  $signature = $func->type()." ".$wordList[$#wordList]."(";
	}
	else{
		$signature = $wordList[$#wordList]."(";
	} 
		
	my $first = 1;
	foreach my $param ($func->ents("Define", "Parameter")){
		$signature = $signature."," unless $first;
		$signature = $signature.$param->type();			
		$first = 0;
	}		
	
	$signature = $signature.")";
	
	return $signature;	
}#END sub getFuncSignature

sub getAttributeSignature{
	#类名+"::"+属性名
	my $sClass = shift;
	my $attribute = shift;
	
	my $signature = getLastName($sClass->name())."::".getLastName($attribute->name());
	
	return $signature;	
}#END sub getFuncSignature


sub NMO{
	my $sClass = shift;	
	my $sAncestorHash = shift;
	
	print "\t\t\t computing NMO..." if ($debug);
	
	my %ancestorHash = %{$sAncestorHash};	#之所以用Hash表, 考虑多继承的情况
	
	my %methodInAncestor; # 祖先类中的方法集
	
	foreach my $key (keys %ancestorHash){
		my $ancestorClass = $ancestorHash{$key};
		
		my @funcList = getEntsInClass($ancestorClass, "Define", "Function ~private,Method ~private");
		
		foreach my $func (@funcList){
			my $signature = getFuncSignature($func, 1);
			$methodInAncestor{$signature} = 1;
		}
	}
	
	my $result = 0;
	
	my @currentFuncList = getEntsInClass($sClass, "Define", "Function ~private ~unresolved,Method ~private ~unresolved");
	
	foreach my $func (@currentFuncList){
		my $currentSignature = getFuncSignature($func, 1);
		$result++ if (exists $methodInAncestor{$currentSignature});		
	}
		
	print "...NMO END\n" if ($debug);
	
	return $result;
}#END sub NMO


sub NMI{
	my $sClass = shift;	
	my $sAncestorHash = shift;
	
	print "\t\t\t computing NMI..." if ($debug);
	
	my %ancestorHash = %{$sAncestorHash};	#之所以用Hash表, 考虑多继承的情况
	
	my %methodInAncestor; # 祖先类中的方法集
	
	foreach my $key (keys %ancestorHash){
		my $ancestorClass = $ancestorHash{$key};
		
		my @funcList = getEntsInClass($ancestorClass, "Define", "Function ~private,Method ~private");
		
		foreach my $func (@funcList){
			my $signature = getFuncSignature($func, 1);
			$methodInAncestor{$signature} = 1;
		}
	}
	
	my $count = 0;
	
	my @currentFuncList = getEntsInClass($sClass, "Define", "Function ~private ~unresolved,Method ~private ~unresolved");
	
	foreach my $func (@currentFuncList){
		my $currentSignature = getFuncSignature($func, 1);
		$count++ if (exists $methodInAncestor{$currentSignature});		
	}
		
	my $result = (keys % methodInAncestor) - $count;
	
	print "...NMI END\n" if ($debug);
			
	return $result;
}#END sub NMI


sub NMA{
	my $sClass = shift;	
	
  print "\t\t\t computing NMA..." if ($debug);	

	my %addedMethodHash;	
	getAddedMethods($sClass, \%addedMethodHash);
	
	my $result = 0;
	$result = (keys %addedMethodHash);	
	
	print "...NMA END\n" if ($debug);
		
	return $result;
}#END sub NMA



sub SIX{
	my $sNMO = shift;
	my $sNMA = shift;
	my $sNMI = shift;
	my $sDIT = shift;
	
	return 0 if (($sNMO + $sNMA + $sNMI) == 0);
	
	my $result = 0;
	$result = $sNMO * $sDIT / ($sNMO + $sNMA + $sNMI);
	
	return $result;
}#END sub SIX


sub PII{
  my $sNPBM = shift; 
	my $sNMO = shift;
	my $sNMA = shift;
	my $sNMI = shift;
	my $sDIT = shift;
	
	my $valuePP = 0;	
	if ($sNMO > 0){
		$valuePP = ($sNMO - $sNPBM) / $sNMO;
	}
	
	my $valueOO = 0;	
	if ($sNMO + $sNMI > 0){
		$valueOO = $sNMO / ($sNMO + $sNMI);
	}

	my $valueNN = 0;	
	$valueNN = $sDIT / ($sDIT + 1) * $sNMA / ($sNMA + 1);
	
	my $valuePII = ($valuePP + $valueOO + $valueNN) / 3;

	return $valuePII;
}#END sub PII


sub getNoOfPBRdM{
	my $sClass = shift;
	my $sAncestorHash = shift;
	my $sAncestorLevel = shift;	
	
	my $valueNPBRdM = 0; 

	my @methodArray = getEntsInClass($sClass, "define", "function ~private ~unknown ~unresolved, method ~private ~unknown ~unresolved");
	foreach my $localFunc (@methodArray){
		my $localSignature = getFuncSignature($localFunc, 1);
		
		my $find = 0; #找到overriden的方法?
	
	  #在祖先类中查找被overiding的方法
	  
	  FINDLOOP:  #在某个祖先类中找到了同基调的方法, 立即跳出查找循环
	  foreach my $level (sort keys %{$sAncestorLevel}){
		  my %ancestorKeyHash = %{$sAncestorLevel->{$level}};
		  
		  foreach my $classKey (keys %ancestorKeyHash){
			  my $ancestorClass = $sAncestorHash->{$classKey};			
			  my @ancestorMethodArray = getEntsInClass($ancestorClass, "define", "function ~private ~unknown, method ~private ~unknown");
			  
			  foreach my $ancestorFunc (@ancestorMethodArray){
				  my $ancestorSignature = getFuncSignature($ancestorFunc, 1);
				  
				  if ($ancestorSignature eq $localSignature){ #如果找到, 则计算	
				  	my $temp = isBehaviorPreserved($sClass, $localFunc, $ancestorClass, $ancestorFunc);	  	
#				  	print "\t\t\t Behavior Preserved? = ", $temp, "\n";
				  	$valueNPBRdM = $valueNPBRdM + $temp;				  	
				  	$find = 1;
				  	last FINDLOOP;		#在某个祖先类中找到了同基调的方法, 立即跳出查找循环		  	
				  }#END if				  
				}#END for				
			}
			
		}
	}
				  
  return $valueNPBRdM;
}#END sub getNoOfPBRdM


sub isBehaviorPreserved{
	#两种情况下认为是behavior preserved: (1)祖先类的方法是空方法; (2)当前类的方法调用了祖先类的方法, 进行了行为扩展
	my $sClass = shift;
	my $sLocalFunc = shift;
	my $sAncestorClass = shift;
	my $sAncestorFunc = shift;
	
	#判断祖先类的方法中没有可执行语句. 注意: 一定要用"CountStmtExe"
	#不能用"CountStmt". 原因: Java的方法即使没有体, metric("CountStmt")都返回1
	return 1 if (!$sAncestorFunc->metric("CountStmtExe")); 
	
  my ($lexer, $startLine, $endLine) = getLexerStartAndEndLine($sLocalFunc);
  return 0 if ($lexer eq "undef");
  
	my @calledMethodSet = $sLocalFunc->refs("call", "function ~unknown ~unresolved, method ~unknown ~unresolved");
	my $ancestorFuncCalled = 0;	
	
	my $localFuncSignature = getFuncSignature($sLocalFunc, 1);
		
	my $i = 0;		
	while ($i < @calledMethodSet && !$ancestorFuncCalled){		
		my $calledFunc = $calledMethodSet[$i]->ent();
		$i++;
		
		next if (getFuncSignature($calledFunc, 1) ne $localFuncSignature); #若调用不同基调的方法, 跳过
		
		my $calledClass = $calledFunc->ref("Definein", "class");
		next if (!$calledClass);
		
		next if (getClassKey($calledClass->ent()) ne getClassKey($sAncestorClass));
		
		$ancestorFuncCalled = 1;
	}	  
	
	return 1 if ($ancestorFuncCalled);
			
	return 0;
}#END sub isBehaviorPreserved


sub MI{
	my $sClass = shift;
	
	my $MI = "undef";
	
  my @methodArray = getRefsInClass($sClass, "define","function ~unknown ~unresolved,  method ~unknown ~unresolved");    
  my $classFuncCount = scalar(@methodArray);    
  
  my $classLineCount = 0;
  my $classComplexitySum = 0;
  
  my %class_metric = ();
  
  foreach my $method (@methodArray){
  	my $func = $method->ent();
  	
		my ($lexer, $startLine, $endLine) = getLexerStartAndEndLine($func);
		next if ($lexer eq "undef");
	  
	  my ($n1, $n2, $N1, $N2) = scanEntity($lexer,$startLine,$endLine);
	  
	  # do the calcs
	  my ($n, $N) = ($n1 + $n2, $N1 + $N2);
	 	
	 	#avoid log of 0 error    
    $n = 1 if ($n <= 0);
        
	  my $V = $n ? $N * ((log $n)/(log 2)) : 0;
	
    #Sum data for class
	  $classLineCount  += $func->metric("CountLine");	  
	  $classComplexitySum += $func->metric("CyclomaticStrict");
	
	  # add them to the class-based metrics
	  $class_metric{V} += $V;
   }  
    
        
   # if this class has functions defined, report totals for the class
   if (@methodArray > 0){
    	
    	#**********compute MI****************
      my ($avG, $avV, $avLoc, $perCM);
   
      #calculate average V, make it 1 if 0 to avoid log error.     
      if ($class_metric{V} == 0){
        $avV = 1;
      }
      else{
        $avV = $class_metric{V} / $classFuncCount;
      }  
        
      $avG = $classComplexitySum / $classFuncCount;
      $avLoc = $classLineCount / $classFuncCount;
      $perCM = $sClass->metric("RatioCommentToCode")*100;
               
      if ($avLoc == 0){
        $avLoc = 1;          	
      }                    

      
	    $MI =  171-5.2 * log($avV)-.23*$avG-16.2*log($avLoc) + 50 * sin(sqrt(2.4 * $perCM));  		
   }

   return $MI;
} # END sub MI


sub LCOMSeriesAndCAC{
	my $sClass = shift;
	my $sHashMetrics = shift; 
   
  my %AttributeReadTable = ();
  my %AttributeWriteTable = ();
  my %AttributeModifyTable = ();
  my %MethodWithoutAttributeParaTable = ();
  my %AttributeWithoutAccessTable = ();
  my %DirectCallMethodSet = ();  
   
  if (buildAttributeHashTables($sClass, 0, 0, 0, 0,
            \%AttributeReadTable, \%AttributeWriteTable, \%AttributeModifyTable, 
            \%MethodWithoutAttributeParaTable, \%AttributeWithoutAccessTable, \%DirectCallMethodSet)){
   
      my %noForMethod = ();
      
      my $attributeMethodMatrix = hashTable2Matrix(\%noForMethod, \%AttributeReadTable, \%AttributeWriteTable, 
                           \%AttributeModifyTable, \%MethodWithoutAttributeParaTable, \%AttributeWithoutAccessTable);
                           
      $sHashMetrics->{Cohesion}->{CAC} = CAC($attributeMethodMatrix);                     
   
      my @methodMethodMatrix = generateMethodMethodMatrix($attributeMethodMatrix, \%noForMethod, 0, \%DirectCallMethodSet);

      $sHashMetrics->{Cohesion}->{LCOM1} = LCOM1(\@methodMethodMatrix);
      $sHashMetrics->{Cohesion}->{LCOM2} = LCOM2(\@methodMethodMatrix);
      $sHashMetrics->{Cohesion}->{LCOM3} = LCOM3(\@methodMethodMatrix);       
      $sHashMetrics->{Cohesion}->{LCOM5} = LCOM5($attributeMethodMatrix);
#      $sHashMetrics->{Cohesion}->{NewLCOM5} = NewLCOM5($attributeMethodMatrix);
       
      my @methodMethodMatrix2 = generateMethodMethodMatrix($attributeMethodMatrix, \%noForMethod, 1, \%DirectCallMethodSet);
              
      $sHashMetrics->{Cohesion}->{LCOM4} = LCOM3(\@methodMethodMatrix2);       
      $sHashMetrics->{Cohesion}->{Co} = Co(\@methodMethodMatrix2);
#      $sHashMetrics->{Cohesion}->{NewCo} = NewCo(\@methodMethodMatrix2);
  }  
  
  $sHashMetrics->{Cohesion}->{LCOM6} = LCOM6($sClass);
} #End sub LCOMSeries



sub TCCLCCSeries{
	my $sClass = shift;
	my $sHashMetrics = shift; 
   
  my %AttributeReadTable = ();
  my %AttributeWriteTable = ();
  my %AttributeModifyTable = ();
  my %MethodWithoutAttributeParaTable = ();
  my %AttributeWithoutAccessTable = ();
  my %DirectCallMethodSet = ();  	

  if (buildAttributeHashTables($sClass, 1, 1, 0, 1,
             \%AttributeReadTable, \%AttributeWriteTable, \%AttributeModifyTable, 
             \%MethodWithoutAttributeParaTable, \%AttributeWithoutAccessTable, \%DirectCallMethodSet)){    
          
      my %noForMethod = ();

      my $attributeMethodMatrix = hashTable2Matrix(\%noForMethod, \%AttributeReadTable, \%AttributeWriteTable, 
                           \%AttributeModifyTable, \%MethodWithoutAttributeParaTable, \%AttributeWithoutAccessTable);

                        
      my @methodMethodMatrix = generateMethodMethodMatrix($attributeMethodMatrix, \%noForMethod, 0, \%DirectCallMethodSet);

      $sHashMetrics->{Cohesion}->{TCC} = TCC(\@methodMethodMatrix);
      $sHashMetrics->{Cohesion}->{LCC} = LCC(\@methodMethodMatrix);
      
      my %indirectCallByMethodSet = getIndirectCallByMethodSet(\%DirectCallMethodSet);
      my @methodMethodMatrix3 = generateMethodMethodMatrix($attributeMethodMatrix, \%noForMethod, 2, \%indirectCallByMethodSet);
      
      $sHashMetrics->{Cohesion}->{DCd} = TCC(\@methodMethodMatrix3);
      $sHashMetrics->{Cohesion}->{DCi} = LCC(\@methodMethodMatrix3);            
   }	
	
} # End sub TCCLCCSeries



sub CBMCSeries{
	my $sClass = shift;
	my $sHashMetrics = shift;

  my %AttributeReadTable = ();
  my %AttributeWriteTable = ();
  my %AttributeModifyTable = ();
  my %MethodWithoutAttributeParaTable = ();
  my %AttributeWithoutAccessTable = ();
  my %DirectCallMethodSet = ();  

   
  if (buildAttributeHashTables($sClass, 0, 1, 1, 1,
             \%AttributeReadTable, \%AttributeWriteTable, \%AttributeModifyTable, 
             \%MethodWithoutAttributeParaTable, \%AttributeWithoutAccessTable, \%DirectCallMethodSet)){                           
             	
      my %noForMethod = ();
      
      my ($attributeMethodMatrix, $noOfAttributes, $noOfMethods) = hashTable2Matrix(\%noForMethod, \%AttributeReadTable, \%AttributeWriteTable, 
                           \%AttributeModifyTable, \%MethodWithoutAttributeParaTable, \%AttributeWithoutAccessTable);
      
      if ($noOfMethods == 0 && $noOfAttributes > 1 
        || $noOfMethods > 1 && $noOfAttributes == 0){ 
        	$sHashMetrics->{Cohesion}->{CBMC} = 0;
        	$sHashMetrics->{Cohesion}->{ICBMC} = 0;
        }
      else{     
        	# $sHashMetrics->{Cohesion}->{CBMC} = CBMC($attributeMethodMatrix);
        	# $sHashMetrics->{Cohesion}->{ICBMC} = ICBMC($attributeMethodMatrix);
        }
    }
} # End sub CBMCSeries


sub OCCAndPCC{
	my $sClass = shift;
	my $sHashMetrics = shift;   
	
	my %AttributeReadTable = ();
  my %AttributeWriteTable = ();
  my %AttributeModifyTable = ();
  my %MethodWithoutAttributeParaTable = ();
  my %AttributeWithoutAccessTable = ();
  my %DirectCallMethodSet = (); 

  if (buildAttributeHashTables($sClass, 0, 0, 0, 1,
             \%AttributeReadTable, \%AttributeWriteTable, \%AttributeModifyTable, 
             \%MethodWithoutAttributeParaTable, \%AttributeWithoutAccessTable, \%DirectCallMethodSet)){                           
   
      my %noForMethod = ();
      
      my $attributeMethodMatrix = hashTable2Matrix(\%noForMethod, \%AttributeReadTable, \%AttributeWriteTable, 
                           \%AttributeModifyTable, \%MethodWithoutAttributeParaTable, \%AttributeWithoutAccessTable);
       
      my @methodMethodMatrix = generateMethodMethodMatrix($attributeMethodMatrix, \%noForMethod, 0, \%DirectCallMethodSet);
      
      $sHashMetrics->{Cohesion}->{OCC} = OCC(\@methodMethodMatrix);
      $sHashMetrics->{Cohesion}->{PCC} = PCC(\%AttributeReadTable, \%AttributeWriteTable, 
                 \%AttributeModifyTable, \%MethodWithoutAttributeParaTable);            
   }
} #End sub OCCandPCC


sub CAMCSeries{	
	my $sClass = shift;
	my $sHashMetrics = shift;	
  
  my %ParaTable = ();
	 
  if (buildParameterHashTable($sClass, 0, 0, 0, 0, \%ParaTable)){ #至少有一个方法
      my @testParaTable = (keys %ParaTable);         
      
      if (scalar @testParaTable == 1 && $testParaTable[0] eq "withoutParameterAndAttribute"){      	
#   	    $sHashMetrics->{Cohesion}->{CAMCs} = 1;
#   	    $sHashMetrics->{Cohesion}->{NHDs} = 1;
#   	    $sHashMetrics->{Cohesion}->{SNHDs} = 1;   	    
      }
      else{#至少有一个方法有参数      	
      	my %noForMethod = ();
      	
   	    my $parameterTypeMethodMatrix = hashTable2Matrix(\%noForMethod, \%ParaTable);    
   	     
   	    my ($CAMC, $CAMCs) = CAMC($parameterTypeMethodMatrix);
   	    my ($NHD, $NHDs) = NHD($parameterTypeMethodMatrix);
   	    my $SNHD = SNHD($parameterTypeMethodMatrix);  	
   	    my $SNHDs = SNHDs($parameterTypeMethodMatrix);  
   	     
   	    $sHashMetrics->{Cohesion}->{CAMC} = $CAMC;
#   	    $sHashMetrics->{Cohesion}->{CAMCs} = $CAMCs;
   	    $sHashMetrics->{Cohesion}->{NHD} = $NHD;
#   	    $sHashMetrics->{Cohesion}->{NHDs} = $NHDs;
   	    $sHashMetrics->{Cohesion}->{SNHD} = $SNHD;
#   	    $sHashMetrics->{Cohesion}->{SNHDs} = $SNHDs;
   	  }
   	}
   

#   if (buildParameterHashTable($sClass, 0, 0, 0, 1, \%ParaTable)){                               	
#      
#      my @testParaTable = (keys %ParaTable);   
#      
#      if (scalar @testParaTable == 1 && $testParaTable[0] eq "withoutParameterAndAttribute"){
#      	# 什么都不用做, 因为相应度量的默认值是undefined       
#   	    $sHashMetrics->{Cohesion}->{iCAMCs} = 1;
#   	    $sHashMetrics->{Cohesion}->{iNHDs} = 1;      	
#   	    $sHashMetrics->{Cohesion}->{iSNHDs} = 1; 
#      }
#      else{
#      	my %noForMethod = ();
#      	
#   	    my $parameterTypeMethodMatrix = hashTable2Matrix(\%noForMethod, \%ParaTable);    
#   	     
#   	    my ($iCAMC, $iCAMCs) = CAMC($parameterTypeMethodMatrix);
#   	    my ($iNHD, $iNHDs) = NHD($parameterTypeMethodMatrix);
#   	    my $iSNHD = SNHD($parameterTypeMethodMatrix);  	   	    
#   	    my $iSNHDs = SNHDs($parameterTypeMethodMatrix);  	   	    
#   	    
#   	    $sHashMetrics->{Cohesion}->{iCAMC} = $iCAMC;
#   	    $sHashMetrics->{Cohesion}->{iCAMCs} = $iCAMCs;
#   	    $sHashMetrics->{Cohesion}->{iNHD} = $iNHD;
#   	    $sHashMetrics->{Cohesion}->{iNHDs} = $iNHDs;
#   	    $sHashMetrics->{Cohesion}->{iSNHD} = $iSNHD;
#   	    $sHashMetrics->{Cohesion}->{iSNHDs} = $iSNHDs;
#   	  }
#   	}
} # Endsub CAMCSeries


sub SCOM{
	#目前只对C++程序有效
	#对Java程序似乎有点问题, 返回的"undef"太多
	my $sClass = shift;
	
	print "\t\t\t computing SCOM..." if ($debug);
	
	my %AttributeReadTable = ();
  my %AttributeWriteTable = ();
  my %AttributeModifyTable = ();
  my %MethodWithoutAttributeParaTable = ();
  my %AttributeWithoutAccessTable = ();
  my %DirectCallMethodSet = ();  
   
  if (buildAttributeHashTables($sClass, 0, 0, 1, 1,
            \%AttributeReadTable, \%AttributeWriteTable, \%AttributeModifyTable, 
            \%MethodWithoutAttributeParaTable, \%AttributeWithoutAccessTable, \%DirectCallMethodSet)){   
            	
      my %methodAttributeHashTable; #用来记录每个方法直接或者间接访问的属性
      my %attributeHashTable;  #用来统计属性的数目
      
      foreach my $attributeKey (keys %AttributeReadTable){
      	my %tempMethodHash = %{$AttributeReadTable{$attributeKey}};
      	$attributeHashTable{$attributeKey} = 1;
      	foreach my $methodKey (keys %tempMethodHash){
      		$methodAttributeHashTable{$methodKey}->{$attributeKey} = 1;
      	}
      }
            	
      foreach my $attributeKey (keys %AttributeWriteTable){
      	my %tempMethodHash = %{$AttributeWriteTable{$attributeKey}};
      	$attributeHashTable{$attributeKey} = 1;
      	foreach my $methodKey (keys %tempMethodHash){
      		$methodAttributeHashTable{$methodKey}->{$attributeKey} = 1;
      	}
      }
            	
      foreach my $attributeKey (keys %AttributeModifyTable){
      	my %tempMethodHash = %{$AttributeModifyTable{$attributeKey}};
      	$attributeHashTable{$attributeKey} = 1;
      	foreach my $methodKey (keys %tempMethodHash){
      		$methodAttributeHashTable{$methodKey}->{$attributeKey} = 1;
      	}
      }           	      
     
      my $noOfAttributes = (keys %attributeHashTable); #属性数目, 只统计被方法访问的属性
      my $noOfMethods = (keys %methodAttributeHashTable); #方法数目, 只统计访问属性的方法
      
      return 1 if ($noOfMethods == 1);
      return 0 if ($noOfAttributes < 1);
      
      my @methodAttributeTable; 
      
      my $ii = 0;
      foreach my $key (keys %methodAttributeHashTable){
      	$methodAttributeTable[$ii] = $methodAttributeHashTable{$key};
      	$ii++;
      }
      

#      for (my $i = 0; $i < $noOfMethods; $i++){
#      	print "\t\t i = ", $i, "\n";
#      	my %tempHash = %{$methodAttributeTable[$i]};
#      	foreach my $att (keys %tempHash){
#      		print "\t\t\t attribute = ", $att, "\n";
#      	}
#      }
      
      
      my $sum = 0; 
      
      for (my $i = 0; $i < $noOfMethods - 1; $i++){
      	for (my $j = $i + 1; $j < $noOfMethods; $j++){
      		my $Cij = CardIntersection($methodAttributeTable[$i],$methodAttributeTable[$j]); #联结强度
      		
      		if ($Cij){
      			my $min = (keys %{$methodAttributeTable[$i]});
      			$min = (keys %{$methodAttributeTable[$j]}) if ($min > (keys %{$methodAttributeTable[$j]}));
      			
      			$Cij = $Cij / $min;
      		}
      		
      		my $Wij;   #相应的权值 
      		$Wij = CardUnion($methodAttributeTable[$i],$methodAttributeTable[$j]) / $noOfAttributes;
      		
      		$sum = $sum + $Cij * $Wij;
      		
#      		print "\t\t i = ", $i, "\t j= ", $j, ": \t";
#      		print "C = ", $Cij, "; \t";
#      		print "W = ", $Wij, "\n";
      	}
      }
      
      my $result = 2 * $sum / ($noOfMethods * ($noOfMethods - 1));
           
      print "...SCOM END\n" if ($debug);
      
      return $result;
  }	
  
  print "...SCOM END\n" if ($debug);
  return "undef";
}#END sub SCOM


sub CardIntersection{
	#给定两个Hash表, 返回它们key相同的数目
	my $sHashTableOne = shift;
	my $sHashTableTwo = shift;
	
	my $smallHashTable;
	my $largeHashTable;
	
	if ((keys %{$sHashTableOne}) > (keys %{$sHashTableTwo})){
		$smallHashTable = $sHashTableTwo;
		$largeHashTable = $sHashTableOne;
	}
	else{
		$smallHashTable = $sHashTableOne;
		$largeHashTable = $sHashTableTwo;
	}
		
	my $result = 0;
	
	foreach my $key (keys %{$smallHashTable}){
		next if (!exists $largeHashTable->{$key});
		$result++;
	}
	
	return $result;
} #END sub CardIntersection


sub CardUnion{
	#给定两个Hash表, 返回它们key并集的数目
	my $sHashTableOne = shift;
	my $sHashTableTwo = shift;
	
	my %unionHashTable;
	
	foreach my $key (keys %{$sHashTableOne}){
		$unionHashTable{$key} = 1;
	}

	foreach my $key (keys %{$sHashTableTwo}){
		$unionHashTable{$key} = 1;
	}
	
	my $result = 0;
	
	$result = (keys %unionHashTable);
	
	return $result;
}#END sub CardUnion


sub CAC{	
	#参数:属性-方法矩阵
	#返回值: CAC数值
	my $inputMatrix = shift;	

	#如果所有方法都不访问属性, 则返回0
	return 0 if (@{$inputMatrix} == 0);	
			
  my $noRow = @{$inputMatrix};
	my $noColumn = @{$inputMatrix->[0]};
	
	my $sum = 0;
	my $temp;	
	
	for (my $i = 0; $i < $noRow; $i++){			
		$temp = 0;
		for (my $j = 0; $j < $noColumn; $j++){
			$temp = $temp + $inputMatrix->[$i][$j];
		}		
		
		$sum = $sum + $temp if ($temp > 1);
	}	
	
	my $result = 0;	
	$result = $sum / ($noRow * $noColumn);	
	
	return $result;
}#END sub CAC


sub CDE{
	#计算CDE
	my $class = shift;
	
	my %identifierList = ();
	
	my $sCDE = 0;
	
	my $definein = $class->ref();
	
	return 0 if (!$definein);
	
  my ($lexer, $startLine, $endLine) = getLexerStartAndEndLine($class);
  return 0 if ($lexer eq "undef");
		
	foreach my $lexeme ($lexer->lexemes($startLine, $endLine)){
		if ($lexeme->token() eq "Identifier"){
			if (!exists $identifierList{$lexeme->text()}){
				$identifierList{$lexeme->text()} = 1;
			}
			else{
				$identifierList{$lexeme->text()} = $identifierList{$lexeme->text()} + 1;
			}				
		}			
	}

  
  my %oldHash = ();
  foreach my $key (keys %identifierList){
  	$oldHash{$key} = $identifierList{$key};
  }

		
	#如果方法在类头文件中定义, 则不统计方法体中的标识符			
	my @methodArray = getEntsInClass($class, "define", "function ~unknown ~unresolved, method ~unknown ~unresolved");		
		
	foreach my $func (@methodArray){
		next if (!IsMethodInClassHeader($class, $func));
		
    my ($lexer, $startLine, $endLine) = getLexerStartAndEndLine($func);
    next if ($lexer eq "undef");
    
    $startLine++;  #方法的头不应该去掉
      
	  foreach my $lexeme ($lexer->lexemes($startLine, $endLine)) {
	    if ($lexeme->token() eq "Identifier"){
			  if ($identifierList{$lexeme->text()} <= 1){
				  delete $identifierList{$lexeme->text()};
			  }
			  else{
				  $identifierList{$lexeme->text()}--;
			  }				
		  }				  
		}
		  
	}			

#  foreach my $key (keys %oldHash){
#  	print "\n\t\t";
#  	
#  	my $temp = 0;
#  	$temp = $identifierList{$key} if (exists $identifierList{$key});
#  	
#  	print "(", $key, ",", $oldHash{$key}, "-->", $temp, ")";
#  }
		
		
	my $totalNoOfIdentifer = 0;
		
	foreach my $key (keys %identifierList){
		$totalNoOfIdentifer = $totalNoOfIdentifer + $identifierList{$key};			
	}
		
	$sCDE = 0;
		
	foreach my $key (keys %identifierList){
		$sCDE = $sCDE - $identifierList{$key}/$totalNoOfIdentifer 
		                * log($identifierList{$key}/$totalNoOfIdentifer) / log(2);			
	}		
		
		
#		print "totalNoOfIdentifer = ", $totalNoOfIdentifer, "\n";
#		foreach my $key (keys %identifierList){
#			print $key, "\t\t", $identifierList{$key}, "\n";			
#		}
			
	return $sCDE;
} # End sub CDE



sub CIE{
	#计算CIE
	my $class = shift;
	
	my %identifierList = ();	
	
	my @methodArray = ();
  @methodArray = getRefsInClass($class, "define","function ~unknown ~unresolved,  method ~unknown ~unresolved");
  if (@methodArray == 0){
  	return 0; 	
  }

	
	foreach my $method (@methodArray){
		my $func = $method->ent();
		
    my ($lexer, $startLine, $endLine) = getLexerStartAndEndLine($func);	  
    next if ($lexer eq "undef");

	  foreach my $lexeme ($lexer->lexemes($startLine, $endLine)) {
			if ($lexeme->token() eq "Identifier"){
				if (!exists $identifierList{$lexeme->text()}){
					$identifierList{$lexeme->text()} = 1;
				}
				else{
					$identifierList{$lexeme->text()} = $identifierList{$lexeme->text()} + 1;
				}				
			}				  
		}
	}
	
	my $totalNoOfIdentifer = 0;
		
	foreach my $key (keys %identifierList){
		$totalNoOfIdentifer = $totalNoOfIdentifer + $identifierList{$key};			
	}
		
	my $sCIE = 0;
		
	foreach my $key (keys %identifierList){
		$sCIE = $sCIE - $identifierList{$key}/$totalNoOfIdentifer 
			                * log($identifierList{$key}/$totalNoOfIdentifer) / log(2);			
	}	
			  			
	return $sCIE;
} # END sub CIE


sub WMC{
	my $sClass = shift;
	
#	my @methodArray = getEntsInClass($sClass, "define", "function ~unknown ~unresolved, method ~unknown ~unresolved");	
#	my $result = 0;
#	
#	foreach my $func (@methodArray){	
#	  $result = $result + $func->metric("Cyclomatic");
#  }

  my $result = $sClass->metric("SumCyclomatic");
	
	return $result;
}#END sub WMC


sub SDMC{
	my $sClass = shift;
	
	my @CCfunc;
	
  my @methodArray = getEntsInClass($sClass, "define", "function ~unknown ~unresolved, method ~unknown ~unresolved");	
  my $CCAvg = 0; 
	my $sum = 0;
	
	return 0 if (@methodArray<1);
	
	foreach my $func (@methodArray){	
		my $temp = $func->metric("Cyclomatic");
		push @CCfunc, $temp;
		$CCAvg = $CCAvg + $temp;
  }
  
  $CCAvg = $CCAvg / @CCfunc;  
  
  foreach my $value (@CCfunc){
  	$sum = $sum + ($value - $CCAvg) * ($value - $CCAvg);
  }
  
  my $result = sqrt($sum / @CCfunc);
	
	
	return $result;
}


sub AvgWMC{  
	#the average of cyclomatic complexity of all methods in a class, i.e. CCAvg
	my $sClass = shift;
	
  my $result = 0;  #$sClass->metric("AvgCyclomatic"); 
  my @methodArray = getEntsInClass($sClass, "define", "function ~unknown ~unresolved, method ~unknown ~unresolved");	
  
  return 0 if (@methodArray<1);
  
	my $sum = 0;
	foreach my $func (@methodArray){	
		$sum = $sum + $func->metric("Cyclomatic");
  }
  
  $result = $sum / @methodArray;  
  
  
	return $result;
}


sub CCMax{
	my $sClass = shift;
	
#  my @methodArray = getEntsInClass($sClass, "define", "function ~unknown ~unresolved, method ~unknown ~unresolved");	

  my $result = $sClass->metric("MaxCyclomatic"); 
	
#	foreach my $func (@methodArray){	
#		my $temp = $func->metric("Cyclomatic");
#		next if $result >= $temp;
#		$result = $temp;
#  }
  
	return $result;	
}


sub NTM{ #number of trivial methods (its CC	 = 1)
	my $sClass = shift;
	
  my @methodArray = getEntsInClass($sClass, "define", "function ~unknown ~unresolved, method ~unknown ~unresolved");	
  my $result = 0; 
	
	foreach my $func (@methodArray){	
		my $temp = $func->metric("Cyclomatic");
		next if $temp > 1;
		$result = $result + 1;
  }

	return $result;		
}

sub SLOCExe{
	my $sClass = shift;
	my $result = $sClass->metric("CountLineCodeExe");
	return $result;
}

sub AvgSLOCExePerMethod{
	my $sClass = shift;
	
  my @methodArray = getEntsInClass($sClass, "define", "function ~unknown ~unresolved, method ~unknown ~unresolved");	
  
  return 0 if (@methodArray < 1);
  
  my $result = 0; 
  my $sum = 0;
	
	foreach my $func (@methodArray){	
		$sum = $sum + $func->metric("CountLineCodeExe");
#		print "\t func = ", $func->name(), "\t SLOCExe = ", $func->metric("CountLineCodeExe"), "\t StmtExe = ", $func->metric("CountStmtExe"), "\n";
  }
  
  $result = $sum / @methodArray;  
  	
	return $result;	
}



sub AvgSLOCPerMethod{
	my $sClass = shift;
  
  my @methodArray = getEntsInClass($sClass, "define", "function ~unknown ~unresolved, method ~unknown ~unresolved");	
  
  return 0 if (@methodArray < 1);
  
  my $result = 0; 
  my $sum = 0;
	
	foreach my $func (@methodArray){	
		$sum = $sum + $func->metric("CountLineCode");
#		print "\t func = ", $func->name(), "\t SLOC = ", $func->metric("CountLineCode"), "\n";
  }
  
  $result = $sum / @methodArray;  
  
	return $result;	
}


sub NCM{ #number of class methods declared in a method
	my $sClass = shift;
	my $result = $sClass->metric("CountDeclClassMethod");
	
	return $result;
}


sub NIM{ #number of Instance methods declared in a method
	my $sClass = shift;
	my $result = $sClass->metric("CountDeclInstanceMethod");
	
	return $result;
}


sub NLM{ #number of local methods declared in a method
	my $sClass = shift;
	my $result = $sClass->metric("CountDeclMethod");
	
	return $result;
}





sub CComplexitySerires{
	my $sClass = shift;
	my $sAncestorHash = shift;
	my $sAncestorLevel = shift;
	
	my %totalMethods = (); #该类具有的所有方法: 继承非overriding的 + overriding + 新增加的
	my %totalAttributes = (); #该类具有的所有属性: 继承的 + 局部定义的
	
	#用当前类的方法和属性进行初始化
	my @methodArray = getEntsInClass($sClass, "define", "function ~private ~unknown ~unresolved, method ~private ~unknown ~unresolved");
	foreach my $func (@methodArray){
		my $signature = getFuncSignature($func, 1);
		$totalMethods{$signature} = $func;
	}
	
	my @attributeArray = getEntsInClass($sClass, "define", "Member Object ~unknown ~unresolved, Member Variable ~unknown ~unresolved");
	foreach my $attribute (@attributeArray){
		my $signature = getAttributeSignature($sClass, $attribute);
		$totalAttributes{$signature} = $attribute;
	}
	
	
	#处理继承的方法和属性
	foreach my $level (sort keys %{$sAncestorLevel}){
		my %ancestorHash = %{$sAncestorLevel->{$level}};
		
		foreach my $classKey (keys %ancestorHash){
			my $ancestorClass = $sAncestorHash->{$classKey};
			
			#----添加继承非overiding的方法-----------
			my @ancestorMethodArray = getEntsInClass($ancestorClass, "define", "function ~private ~unknown ~unresolved, method ~private ~unknown ~unresolved");
			foreach my $func (@ancestorMethodArray){
				my $signature = getFuncSignature($func, 1);
				next if (exists $totalMethods{$signature}); #被子孙类overriding了, 所以跳过
				$totalMethods{$signature} = $func;
			}
			
			#----添加属性-----------
			my @ancestorAttributeArray = getEntsInClass($ancestorClass, "define", "Member Object ~unknown ~unresolved, Member Variable ~unknown ~unresolved");
			foreach my $attribute (@ancestorAttributeArray){
				my $signature = getAttributeSignature($ancestorClass, $attribute);
				$totalAttributes{$signature} = $attribute;
			}
		}		
	}
	
	
	#添加当前类中定义的私有方法
	my @methodArray = getEntsInClass($sClass, "define", "function private ~unknown ~unresolved, method private ~unknown ~unresolved");
	foreach my $func (@methodArray){
		my $signature = getFuncSignature($func, 1);
		$totalMethods{$signature} = $func;
	}	
	
#	print "\t total methods ==> ", scalar (keys %totalMethods), "\n";
#	foreach my $signature (keys %totalMethods){
#		print "\t\t ", $signature, "\n";
#	}
#	
#	print "\n\t total attributes ==> ", scalar (keys %totalAttributes), "\n";
#	foreach my $signature (keys %totalAttributes){
#		print "\t\t ", $signature, "\n";
#	}
#	
	
		
	#计算三种复杂性度量值
	
	my ($valueCC1, $valueCC2) = ClassComplexityByLLL(\%totalMethods);
	my $valueCC3 = ClassComplexityByKSW(\%totalMethods, \%totalAttributes);
	
	return ($valueCC1, $valueCC2, $valueCC3);
}#END sub CComplexitySerires


sub ClassComplexityByLLL{
	my $sAllMethodHash = shift;
	
  return (0, 0) if ((keys %{$sAllMethodHash}) < 1);
		
	my $valueCC1 = 0;
	
	my $sumLN = 0;
	my $sumCP = 0;	
			
	foreach my $signature (keys %{$sAllMethodHash}){
		my $func = $sAllMethodHash->{$signature};

#		print "\t\t func = ", $signature, "\n";		

		my $funcLN = LengthOfMethod($func);
		my $funcCP = CPOfMethod($func);

#		print "\t\t\t LN = ",  $funcLN, "\n";
#		print "\t\t\t CP = ",  $funcCP, "\n";
				
		$valueCC1 = $valueCC1 + $funcLN * $funcCP * $funcCP;

		$sumLN = $sumLN + $funcLN;
		$sumCP = $sumCP + $funcCP;
	}
	
	my $valueCC2 = $sumLN * $sumCP * $sumCP;
	
	return ($valueCC1, $valueCC2);
}#END sub ClassComplexityByLLL


sub LengthOfMethod{
	my $sEnt = shift;
	my $sAllMethodHash = shift;
	
	my $func = $sEnt;
  my ($lexer, $startLine, $endLine) = getLexerStartAndEndLine($func);
	return 0 if ($lexer eq "undef");
	  
	my $result = 0;
	
  foreach my $lexeme ($lexer->lexemes($startLine,$endLine)) 
  {
     $result++ if ($lexeme->token eq "Operator" || $lexeme->token eq "Identifier");
  }
  
	return $result;	
}#END sub LengthOfMethod


sub CPOfMethod{
	my $sEnt = shift;
	
	my $func = $sEnt;
	
	#计算Input coupling for this method
	my $result = InputCouplingOfMethod($func);
	
	#计算Output coupling for this method
	#---处理被调用的方法---
	my @calledMethodArray = $func->refs("call", "function ~unknown ~unresolved, method ~unknown ~unresolved");
	foreach my $calledMethod (@calledMethodArray){		
		my $calledFunc = $calledMethod->ent();		
		$result = $result + InputCouplingOfMethod($calledFunc);
	}
	
	#---处理被访问的非局部变量---
	my @variableArray = $func->refs("use, set, modify", "object ~local ~unknown ~unresolved, variable ~local ~unknown ~unresolved");
	$result = $result + scalar @variableArray;
	
	return $result;
}#END sub CPOfMethod



sub InputCouplingOfMethod{
	my $sEnt = shift;
	
	my $func = $sEnt;
		
	my $result = 0;	
	my @parameterList = $func->ents("define", "parameter");
	$result = 1 + scalar @parameterList;	
	$result++ if ($func->type() and $func->type() !~ m/void/i); #如果有返回值, 则增加1	
	
	return $result;	
}#END sub InputCouplingOfMethod



sub ClassComplexityByKSW{
	my $sAllMethodHash = shift;
	my $sAllAttributeHash = shift;
	
	my $methodNodeHash;  #key为基调名, vlaue为{incoming => {节点名=>被调用/次数}, outgoing =>}
	my $attributeNodeHash;
	
	foreach my $signature (keys %{$sAllMethodHash}){
		my $func = $sAllMethodHash->{$signature};		
		
		#处理被调用的方法: <calling--->called>
		my @calledMethodArray = $func->refs("call", "function ~unknown ~unresolved, method ~unknown ~unresolved");
		foreach my $calledMethod (@calledMethodArray){
			my $calledFunc = $calledMethod->ent();
			my $calledSignature = getFuncSignature($calledFunc, 1);
			
			next if (!exists $sAllMethodHash->{$calledSignature}); #只考虑本类中的方法和属性之间的交互
			
			$methodNodeHash->{$signature}->{outgoing}->{$calledSignature}++;
			$methodNodeHash->{$calledSignature}->{incoming}->{$signature}++;
		}


		#处理访问的属性
		#----处理"读依赖": <属性--->方法>-------
		my @attributeReadArray = $func->refs("use", "Member Object ~local ~unknown ~unresolved, Member Variable ~local ~unknown ~unresolved");
		foreach my $attribute (@attributeReadArray){			
			my $attributeClass = $attribute->ent()->ref("definein", "Class ~unknown ~unresolved");
			next if (!$attributeClass);			

			my $attributeSignature = getAttributeSignature($attributeClass->ent(), $attribute->ent());
			
			next if (!exists $sAllAttributeHash->{$attributeSignature}); #只考虑本类中的方法和属性之间的交互
			
			$methodNodeHash->{$signature}->{incoming}->{$attributeSignature}++;
			$attributeNodeHash->{$attributeSignature}->{outgoing}->{$signature}++;
		}
		
		#----处理"写依赖": <方法--->属性>-------
		my @attributeWriteArray = $func->refs("set", "Member Object ~local ~unknown ~unresolved, Member Variable ~local ~unknown ~unresolved");
		foreach my $attribute (@attributeWriteArray){			
			my $attributeClass = $attribute->ent()->ref("definein", "Class ~unknown ~unresolved");
			next if (!$attributeClass);			
						
			my $attributeSignature = getAttributeSignature($attributeClass->ent(), $attribute->ent());
			
			next if (!exists $sAllAttributeHash->{$attributeSignature}); #只考虑本类中的方法和属性之间的交互
			
			$methodNodeHash->{$signature}->{outgoing}->{$attributeSignature}++;
			$attributeNodeHash->{$attributeSignature}->{incoming}->{$signature}++;
		}		
		
		#----处理"修改依赖": <方法--->属性> and <属性--->方法>-------
		my @attributeModifyArray = $func->refs("Modify", "Member Object ~local ~unknown ~unresolved, Member Variable ~local ~unknown ~unresolved");
		foreach my $attribute (@attributeModifyArray){			
			my $attributeClass = $attribute->ent()->ref("definein", "Class ~unknown ~unresolved");
			next if (!$attributeClass);			
						
			my $attributeSignature = getAttributeSignature($attributeClass->ent(), $attribute->ent());
			
			next if (!exists $sAllAttributeHash->{$attributeSignature}); #只考虑本类中的方法和属性之间的交互

			$methodNodeHash->{$signature}->{incoming}->{$attributeSignature}++;
			$methodNodeHash->{$signature}->{outgoing}->{$attributeSignature}++;
			$attributeNodeHash->{$attributeSignature}->{incoming}->{$signature}++;
			$attributeNodeHash->{$attributeSignature}->{outgoing}->{$signature}++;
		}		
	}
	
	
#	print "method Node Hash ===> \n";
#	
#	foreach my $signature (keys %{$methodNodeHash}){
#		print "\t ", $signature, "\n";
#		print "\t\t incoming:\n";
#		if (exists $methodNodeHash->{$signature}->{incoming}){
#			my %incoming = %{$methodNodeHash->{$signature}->{incoming}}; 
#			foreach my $key (keys %incoming){
#				print "\t\t\t ", $key, ",", $incoming{$key}, "\n"; 
#			}
#		}
#
#		print "\t\t outgoing:\n";
#		if (exists $methodNodeHash->{$signature}->{outgoing}){
#			my %outgoing = %{$methodNodeHash->{$signature}->{outgoing}}; 
#			foreach my $key (keys %outgoing){
#				print "\t\t\t", $key, ",", $outgoing{$key}, "\n"; 
#			}
#		}	
#	}
#	
#	
#	print "\n attribute Node Hash ===> \n";
#	
#	foreach my $signature (keys %{$attributeNodeHash}){
#		print "\t ", $signature, "\n";
#		print "\t\t incoming:\n";
#		if (exists $attributeNodeHash->{$signature}->{incoming}){
#			my %incoming = %{$attributeNodeHash->{$signature}->{incoming}}; 
#			foreach my $key (keys %incoming){
#				print "\t\t\t", $key,",", $incoming{$key}, "\n"; 
#			}
#		}
#
#		print "\t\t outgoing:\n";
#		if (exists $attributeNodeHash->{$signature}->{outgoing}){
#			my %outgoing = %{$attributeNodeHash->{$signature}->{outgoing}}; 
#			foreach my $key (keys %outgoing){
#				print "\t\t\t", $key, ",", $outgoing{$key}, "\n"; 
#			}
#		}	
#	}	
	
		
	
	my @probabilityArray; #记录每个节点的概率
	my $sum = 0;   #最后的数值等于总边数的2倍
	
	foreach my $signature (keys %{$methodNodeHash}){
		my $temp = 0;
		
		if (exists $methodNodeHash->{$signature}->{incoming}){
			my %incoming = %{$methodNodeHash->{$signature}->{incoming}};  		
	  	foreach my $key (keys %incoming){
		  	$temp = $temp + $incoming{$key};
		  }
		}
		
		if (exists $methodNodeHash->{$signature}->{outgoing}){	   
			my %outgoing = %{$methodNodeHash->{$signature}->{outgoing}};
			
		  foreach my $key (keys %outgoing){			  
		  	$temp = $temp + $outgoing{$key};
		  }
		}
		
		$sum = $sum + $temp;		
		push @probabilityArray, $temp;
	}
	
	foreach my $signature (keys %{$attributeNodeHash}){
		my $temp = 0;
		
		if (exists $attributeNodeHash->{$signature}->{incoming}){
		  my %incoming = %{$attributeNodeHash->{$signature}->{incoming}};
  		foreach my $key (keys %incoming){
	   		$temp = $temp + $incoming{$key};
		  }
		}
		  
		if (exists $attributeNodeHash->{$signature}->{outgoing}){  
		  my %outgoing = %{$attributeNodeHash->{$signature}->{outgoing}};
  		foreach my $key (keys %outgoing){
	  		$temp = $temp + $outgoing{$key};
		  }
		}
		
		$sum = $sum + $temp;		
		push @probabilityArray, $temp;
	}	
	
	return 0 if ($sum == 0);
	
	my $valueCC3 = 0;
	
	for (my $i = 0; $i < @probabilityArray; $i++){
		$probabilityArray[$i] = $probabilityArray[$i] / $sum;
		$valueCC3 = $valueCC3 - log($probabilityArray[$i]) * $probabilityArray[$i] / log(2);
	}	
	
	return $valueCC3;
}#END sub ClassComplexityByKSW


sub NMIMP{
	my $sClass = shift;
	
#	my $result = $sClass->metric("CountDeclMethod");
  my @methodArray = getEntsInClass($sClass, "define", "function ~unknown ~unresolved, method ~unknown ~unresolved"); 
  my $result = scalar @methodArray;	
  
	# print "\t\t NMIMP = ", $result, "\n";
	
	return $result;
}#END sub NMIMP


sub NAIMP{
	my $sClass = shift;
	
#	my $result = $sClass->metric("CountDeclClassVariable") + $sClass->metric("CountDeclInstanceVariable");

  my @attributeArray = getEntsInClass($sClass, "define", "Member Object ~unknown ~unresolved, Member Variable ~unknown ~unresolved");  
  my $result = scalar @attributeArray;	
	# print "\t\t NAIMP = ", $result, "\n";
	
	my $dit = $sClass->metric("MaxInheritanceTree");
	# print "\t\t DIT = ", $dit, "\n";
	
	return $result;
}



sub UnderstandSLOC{
	my $sClass = shift;
	
	return $sClass->metric("CountLineCode");
}


sub C3{
	my $class = shift;
	
	my %Vocabulary = ();	
	
	my @methodArray = ();
  @methodArray = getRefsInClass($class, "define","function ~unknown ~unresolved,  method ~unknown ~unresolved");
  if (@methodArray < 2){
  	return wantarray?(1,0):1; 	
  }
  
	foreach my $method (@methodArray){
		my $func = $method->ent();
		
    my ($lexer, $startLine, $endLine) = getLexerStartAndEndLine($func);
    next if ($lexer eq "undef");

	  foreach my $lexeme ($lexer->lexemes($startLine, $endLine)) {
			if ($lexeme->token() eq "Identifier"){				
					$Vocabulary{$lexeme->text()}->{$func->id()} = 1;												
			}				  
		}		
	}
	
	my %noForTerm = ();	
	my $jj = 0;
	
	foreach my $termKey (keys %Vocabulary) {
		$noForTerm{$termKey} = $jj;
		$jj++;		
	}
	
	my $lengthOfVector = scalar (keys %Vocabulary);
	
  if ($lengthOfVector < 1){
  	my $temp = @methodArray;
  	#任何两个方法结点之间都不存在边
  	my $specialLCSM = $temp*($temp - 1)/2;  	
  	return wantarray?(0,$specialLCSM):0; 	
  }	
	
	
	my %termVectorForMethods = ();
	
	foreach my $method (@methodArray){
		my $func = $method->ent();
		
    my ($lexer, $startLine, $endLine) = getLexerStartAndEndLine($func);	  
    next if ($lexer eq "undef");
    
	  my %termFrequency = ();
	  my $totalTerm = 0; 
	  
	  foreach my $lexeme ($lexer->lexemes($startLine, $endLine)) {
			next if ($lexeme->token() ne "Identifier");
			$totalTerm++;
			if (!exists $termFrequency{$lexeme->text()}){
				$termFrequency{$lexeme->text()} = 1;
			}				
			else{
				$termFrequency{$lexeme->text()} = $termFrequency{$lexeme->text()} + 1;				
			}				
		}		
		
		foreach my $termKey (keys %termFrequency){
			$termFrequency{$termKey} = $termFrequency{$termKey} / $totalTerm;			
		}		
		
		for (my $i = 0; $i < $lengthOfVector; $i++){
			$termVectorForMethods{$func->id()}->[$i] = 0;
		}
		

		foreach my $termKey (keys %termFrequency){
			my $noDocuments = scalar (keys %{$Vocabulary{$termKey}});		
			$termVectorForMethods{$func->id()}->[$noForTerm{$termKey}] = 
			   $termFrequency{$termKey} * log(@methodArray / $noDocuments) / log(2);			
		}		
	}
	
	my $noMethod = @methodArray;
	
	my @similarityMatrix = ();
	
	for (my $i = 0; $i < $noMethod; $i++){
		for (my $j = 0; $j < $noMethod; $j++){			
			$similarityMatrix[$i][$j] = 0;			
			$similarityMatrix[$j][$i] = 0;			
		}		
	}
	
	
	for (my $i = 0; $i < $noMethod - 1; $i++){
		my $firstMethod = $methodArray[$i]->ent()->id();		
		for (my $j = $i + 1; $j < $noMethod; $j++){
			my $secondMethod = $methodArray[$j]->ent()->id();					
			$similarityMatrix[$i][$j] = 
			      vectorSimilarity($termVectorForMethods{$firstMethod}, $termVectorForMethods{$secondMethod});			
			$similarityMatrix[$j][$i] = $similarityMatrix[$i][$j];
		}		
	}
  
  
  
  my $ACSM = 0;  
  my $sum = 0;
  
  for (my $i = 0; $i < $noMethod; $i++){
  	for (my $j = 0; $j < $noMethod; $j++){
  		$sum = $sum + $similarityMatrix[$i][$j];  		
  	}  	
  }
  
  $ACSM = $sum / ($noMethod * ($noMethod - 1));  
  
  my $sC3 = 0;
  
  $sC3 = $ACSM if ($ACSM > 0);

  my @tempMethodMethodMatrix = ();
  
  for (my $i = 0; $i < $noMethod; $i++){
  	for (my $j = $i; $j < $noMethod; $j++){  		
  		if ($similarityMatrix[$i][$j] > $ACSM){
  			$tempMethodMethodMatrix[$i][$j] = 1;  		
  			$tempMethodMethodMatrix[$j][$i] = 1;
  		}
  		else{
  			$tempMethodMethodMatrix[$i][$j] = 0;  		
  			$tempMethodMethodMatrix[$j][$i] = 0;
  		}
  	}  	
  }

  
  my @intersectionMatrix = ();
  
  for (my $i = 0; $i < $noMethod; $i++){
  	for (my $j = 0; $j < $noMethod; $j++){
  		$intersectionMatrix[$i][$j] = 0;
  	}
  }
  
  for (my $i = 0; $i < $noMethod - 1; $i++){
  	for (my $j = $i + 1; $j < $noMethod; $j++){
  		my @arrayOne = @{$tempMethodMethodMatrix[$i]};
  		my @arrayTwo = @{$tempMethodMethodMatrix[$j]};
  		
  		if (isMethodSimilar(\@arrayOne, \@arrayTwo)){
  			$intersectionMatrix[$i][$j] = 1;
  			$intersectionMatrix[$j][$i] = 1;
  		}  		
  	}
  }
  
  my $sLCSM = LCOM2(\@intersectionMatrix);
  
  return wantarray?($sC3, $sLCSM): $sC3;	
} # End sub C3


sub isMethodSimilar{
	my $arrayOne = shift;
	my $arrayTwo = shift;
	
	my $similar = 0;
	
	my $i = 0;
	
	while (!$similar && $i < @{$arrayOne}){
		$similar = 1 if (($arrayOne->[$i] == 1) && ($arrayTwo->[$i] == 1));
		$i++;
	}
	
	return $similar;	
} # END sub isMethodSimilar


sub vectorSimilarity{
	my $firstVector = shift;
	my $secondVector = shift;
	
	my $sum0 = 0;
	my $sum1 = 0;
	my $sum2 = 0;
	
	
	my $noElem = @{$firstVector};	
	
	for (my $i = 0; $i < $noElem; $i++){
		$sum0 = $sum0 + $firstVector->[$i] * $secondVector->[$i];		
		$sum1 = $sum1 + $firstVector->[$i] * $firstVector->[$i];		
		$sum2 = $sum2 + $secondVector->[$i] * $secondVector->[$i];						
	}
	
  return "Undefined" if ($sum1 == 0 || $sum2 == 0);
  
  my $result = $sum0 / (sqrt($sum1)*sqrt($sum2));
  
  return $result;	
} # END sub vectorSimilarity



sub LCOM1{ 
   #----计算LCOM1-----
   my $sMethodMethodMatrix = shift;
   
   return "undefined" if (@{$sMethodMethodMatrix} == 0);
   return 0 if (@{$sMethodMethodMatrix} == 1);
   
   my $noRowOrCol = @{$sMethodMethodMatrix};   
   my $sLCOM1 = 0;
   
   for (my $i = 0; $i < $noRowOrCol; $i++){
   	for (my $j = 0; $j < $noRowOrCol; $j++){
   		$sLCOM1++ if (($i != $j) && ($sMethodMethodMatrix->[$i][$j] == 0));
   	}
   }    
  
   $sLCOM1 = $sLCOM1 / 2;
    
   return $sLCOM1;
} #END sub LCOM1
  

sub LCOM2{   
   #----计算LCOM2-----
   my $sMethodMethodMatrix = shift;

   return "undefined" if (@{$sMethodMethodMatrix} == 0);
   return 0 if (@{$sMethodMethodMatrix} == 1); 
  
   my $noRowOrCol = @{$sMethodMethodMatrix};
   my $sLCOM2 = 0;
   my $noSimilar = 0;
   my $noNonSimilar = 0;
   
   for (my $i = 0; $i < $noRowOrCol; $i++){
   	for (my $j = 0; $j < $noRowOrCol; $j++){
   		next if ($i == $j);
   		if ($sMethodMethodMatrix->[$i][$j] == 0){
   			$noNonSimilar++;
   		}
   		else
   		{
   			$noSimilar++;
   		}   		
   	}
   }   
   
   $noNonSimilar = $noNonSimilar / 2;
   $noSimilar = $noSimilar / 2;
   
   $sLCOM2 = $noNonSimilar - $noSimilar if ($noNonSimilar - $noSimilar > 0);

   return $sLCOM2;
 } #END sub LCOM2
 
   
sub LCOM3{
   #----计算LCOM3-----
   my $sMethodMethodMatrix = shift;

   return "undefined" if (@{$sMethodMethodMatrix} == 0);
   return 1 if (@{$sMethodMethodMatrix} == 1);

   my $noRowOrCol = @{$sMethodMethodMatrix};
   my $sLCOM3 = 0;
   my @visited;
   
   for (my $i = 0; $i < $noRowOrCol; $i++){
    	$visited[$i] = 0;	
   }
   
   for (my $i = 0; $i < $noRowOrCol; $i++){ 
   	if (!$visited[$i]){  
   		$sLCOM3++;
   		depthFirstSearch($sMethodMethodMatrix, $i,\@visited); 
    }  	
   }
   
   return $sLCOM3;
} # END sub LCOM3
   

sub Co{
   #----计算Co-----
   my $sMethodMethodMatrix = shift;   

   return "undefined" if (@{$sMethodMethodMatrix} == 0);
   return 1 if (@{$sMethodMethodMatrix} == 1);
  
   my $noRowOrCol = @{$sMethodMethodMatrix};     
   my $noEdge = 0;
   my $noVetex = $noRowOrCol;   
   my $sCo = 0;
      
   for (my $i = 0; $i < $noRowOrCol; $i++){
   	for (my $j = 0; $j < $noRowOrCol; $j++){
   		next if ($i == $j);
      $noEdge++ if ($sMethodMethodMatrix->[$i][$j] == 1);
    }
   }
   
   $noEdge = $noEdge / 2; 
   
   if ($noVetex == 2){
   	 return 0 if ($noEdge == 0);
     return 1;
   }   
  
   $sCo = 2 * ($noEdge - $noVetex + 1) / (($noVetex - 1) * ($noVetex - 2));
      
   return $sCo;
} # END sub Co


sub NewCo{
   #----计算NewCo-----
   my $sMethodMethodMatrix = shift;   

   return "undefined" if (@{$sMethodMethodMatrix} == 0);
   return 1 if (@{$sMethodMethodMatrix} == 1);
   
  
   my $noRowOrCol = @{$sMethodMethodMatrix};     
   my $noEdge = 0;
   my $noVetex = $noRowOrCol;   
   my $sNewCo;
      
   for (my $i = 0; $i < $noRowOrCol; $i++){
   	for (my $j = 0; $j < $noRowOrCol; $j++){
   		next if ($i == $j);
      $noEdge++ if ($sMethodMethodMatrix->[$i][$j] == 1);
    }
   }
   
   $noEdge = $noEdge / 2; 
  
   $sNewCo = 2 * $noEdge / ($noVetex * ($noVetex - 1));
   
   return $sNewCo;
} #END sub NewCo
 

sub LCOM5{
   #----计算LCOM5-----
   my $sAttributeMethodMatrix = shift;

   return "undefined" if (@{$sAttributeMethodMatrix} == 0);
   
   my $sLCOM5 = 0;

   my $noRow = @{$sAttributeMethodMatrix};
   my $noCol = @{$sAttributeMethodMatrix->[0]};

   return "undefined" if ($noCol == 0);
   return 0 if ($noCol == 1);
   
   my $sum = 0;   
      
   for (my $i = 0; $i < $noRow; $i++){
   	for (my $j = 0; $j < $noCol; $j++){
      $sum = $sum + 1 if ($sAttributeMethodMatrix->[$i][$j] == 1);
    }
   }
 
   $sLCOM5 = ($noCol - $sum / $noRow) / ($noCol-1);

   return $sLCOM5;
} # END sub LCOM5


sub NewLCOM5{
   #----计算NewCoh, Briand提出的LCOM5变体-----
   my $sAttributeMethodMatrix = shift;

   if ((@{$sAttributeMethodMatrix} == 0) || (@{$sAttributeMethodMatrix->[0]}==0)) {
    	return "undefined";
   }   
    
   my $sNewCoh = 0;

   my $noRow = @{$sAttributeMethodMatrix};
   my $noCol = @{$sAttributeMethodMatrix->[0]};

   my $sum = 0;
   
      
   for (my $i = 0; $i < $noRow; $i++){
   	for (my $j = 0; $j < $noCol; $j++){
      $sum = $sum + 1 if ($sAttributeMethodMatrix->[$i][$j] == 1);
    }
   }
 
   
  $sNewCoh = ($sum / ($noRow * $noCol));
    
  return $sNewCoh;
}	# END sub NewLCOM5


sub LCOM6{
   #----计算LCOM6-----
   my $sClass = shift;
   
   my @methodArray = getEntsInClass($sClass, "define", "function ~unknown, method ~unknown");
   
   return "undefined" if (@methodArray == 0);
      
   my %parameterNameHash; #key为参数名, value为方法名. 表示哪些方法具有该参数. 实际只记录一个方法名
   my %methodNameHash; #key为方法名, value为集合序号. 表示该方法属于哪个集合
   
   my $currentSetNo = 0;  #当前的集合号, 初值为0. 集合从1开始编号
   
   foreach my $func (@methodArray){
   	 my @parameterList = $func->ents("define", "parameter");
   	 
   	 my $hasCommonPara; # 与先前扫描的方法有公共参数?
   	 $hasCommonPara = 0;
   	 foreach my $parameter (@parameterList){
   	 	 if (exists $parameterNameHash{$parameter->name()}){
   	 	 	 $hasCommonPara = 1;    	 	 
   	 	 	 my $previousMethodName = $parameterNameHash{$parameter->name()};
   	 	   $methodNameHash{getFuncSignature($func, 1)} = $methodNameHash{$previousMethodName};
   	 	 }
   	 	 else{
   	 	 	 $parameterNameHash{$parameter->name()} = getFuncSignature($func,1);
   	 	 }
   	 }
   	 
   	 if (!$hasCommonPara){
   	 	 $currentSetNo++;
   	 	 $methodNameHash{getFuncSignature($func,1)} = $currentSetNo;
   	 }
   }
   
   my $result = 0;
   foreach my $key (%methodNameHash){
   	$result = $methodNameHash{$key} if $result < $methodNameHash{$key};
   }
   
   $result = 100 * $result / @methodArray;
  
   return $result;	
}#END sub LCOM6


sub TCC{
   #----计算TCC-----
   my $sMethodMethodMatrix = shift;
   
   return "undefined" if (@{$sMethodMethodMatrix} == 0);
   return 1 if (@{$sMethodMethodMatrix} == 1);
   
   my $noRowOrCol = @{$sMethodMethodMatrix};
   my $NDC = 0;
   my $NP = $noRowOrCol * ($noRowOrCol - 1)/2; 
   my $sTCC = 0;

   for (my $i = 0; $i < $noRowOrCol; $i++){
   	for (my $j = 0; $j < $noRowOrCol; $j++){
   		next if ($i == $j);
   		$NDC++ if ($sMethodMethodMatrix->[$i][$j] == 1);  	
   	}
   }
   $NDC = $NDC / 2;
  
   if ($NP > 0){
   	$sTCC = $NDC / $NP;
   }

   return $sTCC;
} #END sub TCC


sub LCC{
   #----计算LCC-----
   my $sMethodMethodMatrix = shift;
   
   return "undefined" if (@{$sMethodMethodMatrix} == 0);
   return 1 if (@{$sMethodMethodMatrix} == 1);    
   
   
   my $noRowOrCol = @{$sMethodMethodMatrix};
   my $NIC = 0;
   my $NP = $noRowOrCol * ($noRowOrCol - 1)/2;      
   
   my $sLCC = 0;
   
   my @visited;
   my @noElemOfsubG = (); #每个连通子图中包含的结点个数
   
   for (my $i = 0; $i < $noRowOrCol; $i++){
    	$visited[$i] = 0;	
   }
   
   for (my $i = 0; $i < $noRowOrCol; $i++){ 
   	if (!$visited[$i]){     		
   		my $before = 0;
   		for (my $j = 0; $j < $noRowOrCol; $j++){
   			$before++ if ($visited[$j] == 1);
   		}
   		depthFirstSearch($sMethodMethodMatrix, $i,\@visited); 
   		my $after = 0;
   		for (my $j = 0; $j < $noRowOrCol; $j++){
   			$after++ if ($visited[$j] == 1);
   		}
   		push @noElemOfsubG, $after - $before;   		
    }  	
   }

   for (my $i = 0; $i < @noElemOfsubG; $i++){
     $NIC = $NIC + $noElemOfsubG[$i]*($noElemOfsubG[$i] - 1) / 2;
   }
   
   if ($NP > 0){
   	$sLCC = $NIC / $NP;   
   }

   return $sLCC;
} # END sub LCC
 
 
 
sub OCC{
   #----计算OCC-----
   my $sMethodMethodMatrix = shift;	 
   
   #记录从每个方法出发遍历可到达的方法数   
  
   my $noElem = @{$sMethodMethodMatrix};
   
   return "Undefined" if ($noElem == 0 );   
   return 0 if ($noElem == 1);
   
   my @NoOfRechableMethods = ();
   my @visited;  
   my $count = 0;
   
 
   for (my $node = 0; $node < $noElem; $node++){

   	  for (my $j = 0; $j < $noElem; $j++){
   		  $visited[$j] = 0;	
   	  }    	
   	
    	depthFirstSearch($sMethodMethodMatrix, $node,\@visited);     	    	
    	
    	$count = 0;
 	   	for (my $j = 0; $j < $noElem; $j++){
   		   $count++ if ($visited[$j] == 1);
   	  }
   	
   	  $NoOfRechableMethods[$node] = $count - 1;   	   	  
   }
   
   
   my $max = 0;
   
   for (my $node = 0; $node < $noElem; $node++){
   	 $max = $NoOfRechableMethods[$node] if ($NoOfRechableMethods[$node] > $max);   
   }
   
   my $sOCC = $max / ($noElem - 1);
      
   return $sOCC; 
} # END sub OCC


sub PCC{
	my $sAttributeReadTable = @_[0];
	my $sAttributeWriteTable = @_[1];
	my $sAttributeModifyTable = @_[2];
	my $sMethodWithoutAttributeParaTable = @_[3];	
	
	
#	print "noOfattributeRead = ", scalar (keys %{$sAttributeReadTable}), "\n";
#	print "noOfattributeWrite = ", scalar (keys %{$sAttributeWriteTable}), "\n";
#	print "noOfattributeModify = ", scalar (keys %{$sAttributeModifyTable}), "\n";
	
	my %allMethodList = ();
	
  foreach my $aHashRef (@_){   	 
  	foreach my $attributeKey (sort keys %{$aHashRef}){
  		my %tempMethodHashTable = %{$aHashRef->{$attributeKey}};
  		foreach my $methodKey (sort keys %tempMethodHashTable){
  			$allMethodList{$methodKey} = 1;
  		}
  	}
  }
  
  my $noElem = scalar (keys %allMethodList);
  
  return "Undefined" if ($noElem == 0);  
  return 0 if ($noElem == 1);
  
  my $jj=0;
  foreach my $methodKey (sort keys %allMethodList){
   	$allMethodList{$methodKey} = $jj;
   	$jj++;  	
  } 

  
  my @tempMethodMethodMatrix = ();
  
    
  for (my $i = 0; $i < $noElem; $i++){
  	for (my $j = 0; $j < $noElem; $j++){
  		$tempMethodMethodMatrix[$i][$j] = 0;
  	} 	
  }
  
  #遍历"属性写和读列表", 建立方法间依赖关系
  
  foreach my $attributeKey (sort keys %{$sAttributeWriteTable}){
  	next if (!exists $sAttributeReadTable->{$attributeKey});
  	
  	my %tempHashTable = $sAttributeWriteTable->{$attributeKey};
  	
  	foreach my $fstMethodKey (keys %{$sAttributeWriteTable->{$attributeKey}}){
  		foreach my $sndMethodKey (keys %{$sAttributeReadTable->{$attributeKey}}){  			  			
  			my $row = $allMethodList{$fstMethodKey};
  			my $col = $allMethodList{$sndMethodKey};  			
  			$tempMethodMethodMatrix[$row][$col] = 1;  			
  		}  		
  	} 	
  } 
  
  #遍历"属性写和修改列表", 建立方法间依赖关系  
  foreach my $attributeKey (sort keys %{$sAttributeWriteTable}){
  	next if (!exists $sAttributeModifyTable->{$attributeKey});
  	
  	foreach my $fstMethodKey (keys %{$sAttributeWriteTable->{$attributeKey}}){
  		foreach my $sndMethodKey (keys %{$sAttributeModifyTable->{$attributeKey}}){  			
  			my $row = $allMethodList{fstMethodKey};
  			my $col = $allMethodList{sndMethodKey};  			
  			$tempMethodMethodMatrix[$row][$col] = 1;  			
  		}  		
  	} 	
  } 
 
  #遍历"属性修改和读列表", 建立方法间依赖关系  
  foreach my $attributeKey (sort keys %{$sAttributeModifyTable}){
  	next if (!exists $sAttributeReadTable->{$attributeKey});
  	
  	foreach my $fstMethodKey (keys %{$sAttributeModifyTable->{$attributeKey}}){
  		foreach my $sndMethodKey (keys %{$sAttributeReadTable->{$attributeKey}}){  			
  			my $row = $allMethodList{fstMethodKey};
  			my $col = $allMethodList{sndMethodKey};  			
  			$tempMethodMethodMatrix[$row][$col] = 1;  			
  		}  		
  	} 	
  } 
  
  my $sPCC = OCC(\@tempMethodMethodMatrix);
  
  return $sPCC; 
} # END sub PCC
 
 
 


#####计算CBMC的函数#########

sub CBMC{
	my $sAttributeMethodMatrix = shift;	
		
	return 1 if (@{$sAttributeMethodMatrix} == 0); #只有一个属性节点或者方法节点的图
	
	return 1 if (isMCC($sAttributeMethodMatrix));
	return 0 if (isDisjoint($sAttributeMethodMatrix));
	
	my @arrayOfGlueMethodSet = getArrayOfGlueMethodSet($sAttributeMethodMatrix);

  my $maxCBMC = 0;

	my $Fs = 0;
	my $Fc = 0;
	
  foreach my $currentGlueMethodSet (@arrayOfGlueMethodSet){    
  	
  	my $noSubGraphs = 0;
  	my @methodArray = ();
  	my @attributeArray = ();
  	
  	my @graphWithoutGlueMethods = excludeGlueMethods($sAttributeMethodMatrix, $currentGlueMethodSet);  	
  	
  	$noSubGraphs = getNumberOfSubGraphs(\@graphWithoutGlueMethods, \@methodArray, \@attributeArray);
  	
  	my $sum;
  	
  	$sum = 0;
  	
  	for (my $i = 1; $i <= $noSubGraphs; $i++){
  		my @aSubGraph = getSubGraph(\@graphWithoutGlueMethods, $i, \@methodArray, \@attributeArray);  		
  		my $temp = CBMC(\@aSubGraph); 		
  		$sum = $sum + $temp;
  	}
  	
  	$Fs = $sum / $noSubGraphs;  	
  	$Fc = @{$currentGlueMethodSet} / @{$sAttributeMethodMatrix->[0]};  	
 	  	
  	$maxCBMC = $Fs * $Fc if ($Fs * $Fc > $maxCBMC);
  }  
  
  return $maxCBMC;	
} # END sub CBMC


sub excludeGlueMethods{
	my $sAttributeMethodMatrix = shift;
	my $sCurrentGlueMethodSet = shift;
	
	my @resultGraph = ();
	
	my @attributeArray = ();
	my @methodArray = ();
	
	for (my $attribute = 0; $attribute < @{$sAttributeMethodMatrix}; $attribute++){
		$attributeArray[$attribute] = $attribute;
	}
	
	for (my $method = 0; $method < @{$sAttributeMethodMatrix->[0]}; $method++){
		next if (findElem($sCurrentGlueMethodSet, $method));
		push @methodArray, $method;		
	}
	
	for (my $row = 0; $row < @attributeArray; $row++){
		for (my $col = 0; $col < @methodArray; $col++){
			$resultGraph[$row][$col] = $sAttributeMethodMatrix->[$attributeArray[$row]][$methodArray[$col]];			
		}		
	}	
		
	return @resultGraph;
} # End Sub excludeGlueMethods




sub getSubGraph{
	#返回第k个子图
	my $sAttributeMethodMatrix = shift;
	my $kthSubGraph = shift;
	my $sMethodInGraph = shift;
	my $sAttributeInGraph = shift;
	
	my @aSubGraph = ();
	my @subGraphAttribute = ();
	my @subGraphMethod = ();
	
	for (my $attribute = 0; $attribute < @{$sAttributeInGraph}; $attribute++){
		next if ($sAttributeInGraph->[$attribute] != $kthSubGraph);
		push @subGraphAttribute, $attribute;		
	}
	
	for (my $method = 0; $method < @{$sMethodInGraph}; $method++){
		next if ($sMethodInGraph->[$method] != $kthSubGraph);
		push @subGraphMethod, $method;		
	}
	
	for (my $row = 0; $row < @subGraphAttribute; $row++){
		for (my $col = 0; $col < @subGraphMethod; $col++){
			$aSubGraph[$row][$col] = $sAttributeMethodMatrix->[$subGraphAttribute[$row]][$subGraphMethod[$col]];			
		}		
	}
	
	return @aSubGraph; 
} # END sub getSubGraph



sub isMCC{
#判断一个图是否是"MCC"(任何一个方法都访问所有的属性)
#Pre: 输入的图是连通图,且至少有一个属性节点和方法节点
   my $sAttributeMethodMatrix = shift;
   
   my $isMCC = 0;
   
   my $noRow = @{$sAttributeMethodMatrix};      
   my $noCol = @{$sAttributeMethodMatrix->[0]};
   
   my $i = 0;
   my $j = 0;
   
   my $findZero = 0;
   
  
   while ($i < $noRow && !$findZero){   	
   	$j = 0;
   	while ($j < $noCol && !$findZero){
  		$findZero = 1 if ($sAttributeMethodMatrix->[$i][$j] == 0); 
   		$j++;   		
   	}
   	$i++;  
   }
  
   $isMCC = 1 if (!$findZero);   	
   	
	 return $isMCC;
} # END sub isMCC
 

sub getArrayOfGlueMethodSet{
	#输入:一个连通图
	#输出: "胶水"方法集数组, 数据结构: 2维数组, 每行对应于一个胶水方法集 (一个连通图可能有多个胶水方法集)
	my $sAttributeMethodMatrix = shift;	 
	my @arrayOfGlueMethodSet = ();
		
	my $found = 0;	#如果发现一个胶水方法集, 立即退出. 因为按定义胶水方法是使得连通图变为非连通图的最小方法集
	my $currentNoElemInGlueMethodSet = 1;  #当前的胶水方法集中包含的元素数目
  my $maxNoElemInGlueMethodSet = @{$sAttributeMethodMatrix->[0]}; #胶水方法集中元素数目的最大值	
    
	while (!$found && $currentNoElemInGlueMethodSet <= $maxNoElemInGlueMethodSet){
		 my $maxNoElem = $maxNoElemInGlueMethodSet - 1; #最大的元素编号, 因为编号是从0开始
		 
		 my @allArrayOfMethodSet = ();
		 my @tempArray = ();
		 
     getSelectedSet(\@allArrayOfMethodSet, \@tempArray, 0, 0, $currentNoElemInGlueMethodSet, $maxNoElem);		
     
     foreach my $currentSet (@allArrayOfMethodSet){     
     	  if (isAGlueMethodSet($sAttributeMethodMatrix, $currentSet)){
     		   my $row = @arrayOfGlueMethodSet;
     		   for (my $col = 0; $col < @{$currentSet}; $col++){
     			    $arrayOfGlueMethodSet[$row][$col] = $currentSet->[$col];     			
     		   }#end for     		
     	  } #end if         	
     }#end for
     
     $found = 1 if (@arrayOfGlueMethodSet);
     $currentNoElemInGlueMethodSet++;	
	}
		
	return @arrayOfGlueMethodSet;	
} # END sub getArrayOfGlueMethodSet
 

sub isAGlueMethodSet{
	my $sAttributeMethodMatrix = shift;	 
	my $sCurrentSet = shift;	
		
	my @tempAttributeMethodMatrix = ();
	
	my $row = @{$sAttributeMethodMatrix};
	my $col = @{$sAttributeMethodMatrix->[0]};
	
	return 1 if ($col == @{$sCurrentSet}); #如果当前方法集中包含所有的方法, 那么它一定是胶水方法集 (属性数目大于1的情况下)
		
	for (my $i = 0; $i < $row; $i++){		
		for (my $j = 0; $j < $col; $j++){
			next if (findElem($sCurrentSet, $j));			
			push @{$tempAttributeMethodMatrix[$i]}, $sAttributeMethodMatrix->[$i][$j];				 		
		}
	}
	
	return 1 if (isDisjoint(\@tempAttributeMethodMatrix));
		
	return 0;
} # END sub isAGlueMethodSet


sub isDisjoint{
	my $sAttributeMethodMatrix = shift;
	
	my $noSubGraphs = 0;
	my @methodArray = ();
	my @attributeArray = ();
	
	$noSubGraphs = getNumberOfSubGraphs($sAttributeMethodMatrix, \@methodArray, \@attributeArray);
	
	return 1 if ($noSubGraphs > 1);
	return 0;
} # END sub isDisjoint
	

sub findElem{
	my $sArray = shift;
	my $sValue = shift;
	
	my $found = 0;	
	my $i = 0;
	
	while (!$found && $i < @{$sArray})
	{
		$found = 1 if ($sArray->[$i] == $sValue);
		$i++;
	}
	
	return $found;
} # End sub findElem


sub getNumberOfSubGraphs{
	#判断一个图是否是连通图
  #输入: 属性方法矩阵
  my $sAttributeMethodMatrix = shift;	 
  my $methodVisited = shift; 
  my $attributeVisited = shift; 
  
  
  #返回值: 三个
  #第一个分量表示该图有几个连通子图
  #第二个分量表示每个方法节点属于哪个子图
  #第三个分量表示每个属性节点属于哪个子图
  
  my $noOfSubGraphs = 0;
  
  my $row = @{$sAttributeMethodMatrix};
  my $col = @{$sAttributeMethodMatrix->[0]};
  
  for (my $attributeNode = 0; $attributeNode < $row; $attributeNode++){
  	$attributeVisited->[$attributeNode] = 0; #0表示没有被访问过, 自然数表示该节点属于第几个子图  	
  }

  for (my $methodNode = 0; $methodNode < $col; $methodNode++){
  	$methodVisited->[$methodNode] = 0; #0表示没有被访问过, 自然数表示该节点属于第几个子图  	
  }
 
  for (my $attributeNode = 0; $attributeNode < $row; $attributeNode++){
  	if ($attributeVisited->[$attributeNode] == 0){
  		$noOfSubGraphs++;
  		dfsForCBMC($sAttributeMethodMatrix, $attributeNode, "attribute", 
  		           $noOfSubGraphs, $methodVisited, $attributeVisited);
  	}
  }
 
  for (my $methodNode = 0; $methodNode < $col; $methodNode++){
  	if ($methodVisited->[$methodNode] == 0){
  		$noOfSubGraphs++;
  		dfsForCBMC($sAttributeMethodMatrix, $methodNode, "method", 
  		           $noOfSubGraphs, $methodVisited, $attributeVisited);
  	}
  }
 
  return $noOfSubGraphs;
} 


sub dfsForCBMC{
	#对属性方法矩阵进行深度优先遍历
	my $sAttributeMethodMatrix = shift;
	my $sCurrentNode = shift;  #当前访问的节点
	my $sNodeType = shift;     #当前节点的类型: 方法还是属性?
	my $sMark = shift;         #给当前节点做的访问标记, 这里使用子图的编号(相同编号的节点属于同一个子图)
	my $sMethodVisited = shift; #存储方法是否已经被访问的信息
	my $sAttributeVisited = shift; #存储属性是否已经被访问的信息
	

	if ($sNodeType eq "method"){
		$sMethodVisited->[$sCurrentNode] = $sMark;
#		print "method node => ", $sCurrentNode, "\n";
		for (my $row = 0; $row < @{$sAttributeMethodMatrix}; $row++){
			next if ($sAttributeMethodMatrix->[$row][$sCurrentNode] == 0); #不是邻节点
			next if ($sAttributeVisited->[$row]);
			dfsForCBMC($sAttributeMethodMatrix, $row, "attribute", $sMark, $sMethodVisited, $sAttributeVisited);			
		} 		
	}
	
	if ($sNodeType eq "attribute"){
		$sAttributeVisited->[$sCurrentNode] = $sMark;
#		print "attribute node => ", $sCurrentNode, "\n";
		for (my $col = 0; $col < @{$sAttributeMethodMatrix->[0]}; $col++){
			next if ($sAttributeMethodMatrix->[$sCurrentNode][$col] == 0); #不是邻节点
			next if ($sMethodVisited->[$col]);
			dfsForCBMC($sAttributeMethodMatrix, $col, "method", $sMark, $sMethodVisited, $sAttributeVisited);			
		} 		
	}
} # End sub dfsForCBMC

 
sub getSelectedSet{
	# 列出所有这样的组合: 从$maxValue+1个数字中任选$noElementsInSet数字
	my $sArrayOfSets = shift; #存放结果
	my $sList = shift; #临时使用的存储空间
	my $sCurrentPosition = shift;
	my $sCurrentValue = shift;
	my $sNoElementsInSet = shift;
	my $sMaxNoElem = shift; #最大的元素编号
	
	
	if ($sCurrentPosition >= $sNoElementsInSet){
		my $count = @{$sArrayOfSets};
		
		for (my $i = 0; $i < @{$sList}; $i++){
#			print $sList->[$i], "\t";
			$sArrayOfSets->[$count]->[$i] = $sList->[$i];
		}
		
#		print "\n";
		return 1;
	}
	
	
	for (my $value = $sCurrentValue; $value <= $sMaxNoElem; $value++){
		$sList->[$sCurrentPosition] = $value;
		getSelectedSet($sArrayOfSets, $sList, $sCurrentPosition + 1, $value + 1, $sNoElementsInSet, $sMaxNoElem);
	}
#	return 0;		
} # END sub getSlectedSet
 
 

#####计算ICBMC的函数#########

sub ICBMC{
	my $sAttributeMethodMatrix = shift;		
	
  print "computing ICBMC.....\n";
  		
	return 1 if (@{$sAttributeMethodMatrix} == 0); #只有一个属性节点或者方法节点的图
	
	return 1 if (isMCC($sAttributeMethodMatrix));
	return 0 if (isDisjoint($sAttributeMethodMatrix));
	
	my @arrayOfGlueEdgeSet = getArrayOfGlueEdgeSet($sAttributeMethodMatrix);

  my $maxICBMC = 0;

	my $Fs = 0;
	my $Fc = 0;
	
  foreach my $currentGlueEdgeSet (@arrayOfGlueEdgeSet){    
  	
  	my $noSubGraphs = 0;
  	my @methodArray = ();   #记录每个方法属于第几个子图
  	my @attributeArray = ();  #记录每个属性属于第几个子图
  	
  	my @graphWithoutGlueEdges = excludeGlueEdges($sAttributeMethodMatrix, $currentGlueEdgeSet);  	
  	
  	$noSubGraphs = getNumberOfSubGraphs(\@graphWithoutGlueEdges, \@methodArray, \@attributeArray);
  	
  	my $sum;
  	
  	$sum = 0;
  	
  	for (my $i = 1; $i <= $noSubGraphs; $i++){
  		my @aSubGraph = getSubGraph(\@graphWithoutGlueEdges, $i, \@methodArray, \@attributeArray);  		
  		my $temp = ICBMC(\@aSubGraph); 		
  		$sum = $sum + $temp;
  	}
  	
  	$Fs = $sum / $noSubGraphs;  	
  	$Fc = @{$currentGlueEdgeSet} / (@methodArray * @attributeArray);
  	# getMaxNoInterEdgesBetweenSubGraphs(\@methodArray, \@attributeArray);  	
 	  	
  	$maxICBMC = $Fs * $Fc if ($Fs * $Fc > $maxICBMC);
  }  
  
  return $maxICBMC;	
} # END sub ICBMC


sub excludeGlueEdges{
	my $sAttributeMethodMatrix = shift;
	my $sCurrentGlueEdgeSet = shift;
	
	my @resultGraph = ();	
	
	for (my $row = 0; $row < @{$sAttributeMethodMatrix}; $row++){
		for (my $col = 0; $col < @{$sAttributeMethodMatrix->[0]}; $col++){
			$resultGraph[$row][$col] = $sAttributeMethodMatrix->[$row][$col];			
		}		
	}	
	
	for (my $i = 0; $i < @{$sCurrentGlueEdgeSet}; $i++){
		$resultGraph[$sCurrentGlueEdgeSet->[$i]->{"Row"}][$sCurrentGlueEdgeSet->[$i]->{"Col"}] = 0;		
	}
		
	return @resultGraph;
} # END sub excludeGlueEdges


sub getArrayOfGlueEdgeSet{
	#输入:一个连通图
	#输出: "胶水"边集数组, 数据结构: 多维数组, 第一维的每个元素对应于一个胶水边集 (一个连通图可能有多个胶水方法集)
	#      在给定第一维元素的情况下, 每个第二维的元素是一个"胶水"边, 它实际上hash表的引用, 每个hash表由2个元素组成
	#      , key为"Row"和"Col".
	
	
	my $sAttributeMethodMatrix = shift;	 
	my @arrayOfGlueEdgeSet = ();
		
	my $found = 0;	#如果发现一个胶水边集, 立即退出. 因为按定义胶水边是使得连通图变为非连通图的最小方法集
	my $currentNoElemInGlueEdgeSet = 1;  #当前的胶水边集中包含的元素数目
	
	my $countEdge = 0;
	my @allEdges = ();
	
	for (my $i = 0; $i < @{$sAttributeMethodMatrix}; $i++){
		for (my $j = 0; $j < @{$sAttributeMethodMatrix->[0]}; $j++){
			if ($sAttributeMethodMatrix->[$i][$j] == 1){
				$allEdges[$countEdge]->{"Row"} = $i;
				$allEdges[$countEdge]->{"Col"} = $j;				
				$countEdge++ ;
			}			
		}
	}
	
  my $maxNoElemInGlueEdgeSet = $countEdge; #胶水方法集元素数目最大值	
    
	while (!$found && $currentNoElemInGlueEdgeSet <= $maxNoElemInGlueEdgeSet){
		 my $maxNoElem = $maxNoElemInGlueEdgeSet - 1; #最大的元素编号, 因为编号是从0开始
		 
		 my @allArrayOfEdgeSet = ();
		 my @tempArray = ();
		 
     getSelectedSet(\@allArrayOfEdgeSet, \@tempArray, 0, 0, $currentNoElemInGlueEdgeSet, $maxNoElem);		
     
     foreach my $currentSet (@allArrayOfEdgeSet){     
     	  my @currentEdgeSet = ();
     	  for (my $i = 0; $i < @{$currentSet}; $i++){
     	  	$currentEdgeSet[$i]->{"Row"} = $allEdges[$currentSet->[$i]]->{"Row"};
     	  	$currentEdgeSet[$i]->{"Col"} = $allEdges[$currentSet->[$i]]->{"Col"};    
     	  }     	  
     	  
     	  if (isAGlueEdgeSet($sAttributeMethodMatrix, \@currentEdgeSet)){
     		   my $row = @arrayOfGlueEdgeSet;
     		   for (my $col = 0; $col < @currentEdgeSet; $col++){
     		   	  $arrayOfGlueEdgeSet[$row][$col]->{"Row"} = $currentEdgeSet[$col]->{"Row"}; 
     		   	  $arrayOfGlueEdgeSet[$row][$col]->{"Col"} = $currentEdgeSet[$col]->{"Col"}; 
     		   }#end for     		
     	  } #end if         	
     }#end for
     
     $found = 1 if (@arrayOfGlueEdgeSet);
     $currentNoElemInGlueEdgeSet++;	
	}
			
	return @arrayOfGlueEdgeSet;	
} # END sub getArrayOfGlueEdgeSet
 

sub isAGlueEdgeSet{
	my $sAttributeMethodMatrix = shift;	 
	my $sCurrentSet = shift;	
		
	my @tempAttributeMethodMatrix = ();
	
	my $row = @{$sAttributeMethodMatrix};
	my $col = @{$sAttributeMethodMatrix->[0]};

	for (my $i = 0; $i < $row; $i++){		
		for (my $j = 0; $j < $col; $j++){
			$tempAttributeMethodMatrix[$i][$j] = $sAttributeMethodMatrix->[$i][$j];				 		
		}
	}
	
	for (my $i = 0; $i < @{$sCurrentSet}; $i++){
		$tempAttributeMethodMatrix[$sCurrentSet->[$i]->{"Row"}][$sCurrentSet->[$i]->{"Col"}] = 0;
	}		
	
	my $noSubGraphs = 0;
	my @methodArray = ();
	my @attributeArray = ();
	
	$noSubGraphs = getNumberOfSubGraphs(\@tempAttributeMethodMatrix, \@methodArray, \@attributeArray);	
		
	return 0 if ($noSubGraphs == 1);
	
	#对每个子图, 记录其节点数(方法数加属性数)
	my @noNodesubGraph = ();
	
	for (my $i = 0; $i < $noSubGraphs; $i++){
		my $elem = $i + 1;
		$noNodesubGraph[$i] = countOccurence(\@methodArray, $elem) + countOccurence(\@attributeArray, $elem);	
	}
	
	
	#子图节点数的最小值
	my $minNode = $noNodesubGraph[0];
	for (my $i = 1; $i < $noSubGraphs; $i++){
		$minNode = $noNodesubGraph[$i] if ($noNodesubGraph[$i] < $minNode);
	}
	
	return 1 if ($minNode > 1);  #如果是胶水边集, 子图至少包含两个节点 	
		
	return 0;
} # END sub isAGlueEdgeSet



sub getMaxNoInterEdgesBetweenSubGraphs{
	my $sMethodArray = shift; #记录每个方法属于第几个子图, 注意最小的子图编号是1
	my $sAttributeArray = shift; #记录每个属性属于第几个子图
	
	my $noSubGraph = 0;
	
	for (my $i = 0; $i < @{$sMethodArray}; $i++){
		$noSubGraph = $sMethodArray->[$i] if ($sMethodArray->[$i] > $noSubGraph);
	}
	
	for (my $i = 0; $i < @{$sAttributeArray}; $i++){
		$noSubGraph = $sAttributeArray->[$i] if ($sAttributeArray->[$i] > $noSubGraph);
	}
	
	
	#对每个子图, 记录其方法数和属性数
	my @subGraphInfo = ();
	
	for (my $i = 0; $i < $noSubGraph; $i++){
		$subGraphInfo[$i]->{"NoOfMethods"} = countOccurence($sMethodArray, $i+1);
		$subGraphInfo[$i]->{"NoOfAttributes"} = countOccurence($sAttributeArray, $i+1);	
	}
	
	my $sum = 0;
	
	for (my $i = 0; $i < $noSubGraph; $i++){
		for (my $j = 0; $j < $noSubGraph; $j++){
			next if ($i == $j);
			$sum = $sum + $subGraphInfo[$i]->{"NoOfMethods"} * $subGraphInfo[$j]->{"NoOfAttributes"};			
		}
	}
		
	return $sum;	
} # END sub getMaxNoInterEdgesBetweenSubGraphs


sub countOccurence{
	my $array = shift;
	my $elem = shift;
	
	my $count = 0;	
	
	for (my $i = 0; $i < @{$array}; $i++){
		$count++ if ($array->[$i] == $elem);	
	}
	
	return $count;
} # END sub countOccurence



#########计算CAMC系列#################### 
 
sub CAMC{
	 #----计算CAMC与CAMCs-----
   my $sParameterTypeMethodMatrix = shift;   

  if (@{$sParameterTypeMethodMatrix} == 0){ #实际上这个条件不可能成立, 因为前面的设置使得至少有一个参数
   	return (0, 0);
  }   
   
   my $sum = 0;   
   my $noRow = @{$sParameterTypeMethodMatrix};
   my $noCol = @{$sParameterTypeMethodMatrix->[0]};
   
   return wantarray?("Undefined","Undefined"):"Undefined" if ($noCol == 0);
   return wantarray?(1, 1):1 if ($noCol == 1);
   
   for (my $i = 0; $i < $noRow; $i++){
   	for (my $j = 0; $j < $noCol; $j++){
   		$sum++ if ($sParameterTypeMethodMatrix->[$i][$j] == 1);
   	}
   }
   
   my $sCAMC = $sum / ($noRow * $noCol);
   my $sCAMCs = ($sum + $noCol) / (($noRow + 1)*$noCol);
   
   return wantarray?($sCAMC, $sCAMCs): $sCAMC;
} # END sub CAMC


sub NHD{
   #----计算NHD与NHDs-----
   my $sParameterTypeMethodMatrix = shift;   

  if (@{$sParameterTypeMethodMatrix} == 0){ #实际上这个条件不可能成立, 因为前面的设置使得至少有一个参数
   	return (0, 0);
  }   
   
   my $sum = 0;
   my $noRow = @{$sParameterTypeMethodMatrix};
   my $noCol = @{$sParameterTypeMethodMatrix->[0]};

   return wantarray?("Undefined","Undefined"):"Undefined" if ($noCol == 0);
   return wantarray?(1, 1):1 if ($noCol == 1);
   
   my @cc;
   
   for (my $i = 0; $i < $noRow; $i++){
   	$cc[$i] = 0;
   	for (my $j = 0; $j < $noCol; $j++){
   		$cc[$i]++ if ($sParameterTypeMethodMatrix->[$i][$j] == 1);
   	}
   }
   
   for (my $i = 0; $i < $noRow; $i++){
   	$sum = $sum + $cc[$i]*($noCol - $cc[$i]);  	
   }
   
   my $sNHD;
   my $sNHDs;
   
   $sNHD = 1 - 2 * $sum / ($noRow * $noCol * ($noCol - 1));
   $sNHDs = 1 - 2 * $sum / (($noRow + 1) * $noCol * ($noCol - 1));
   
   return wantarray?($sNHD, $sNHDs): $sNHD;
 } # END sub NHD
   
   
sub SNHD{
   #----计算SNHD-----
   my $sParameterTypeMethodMatrix = shift;     

  if (@{$sParameterTypeMethodMatrix} == 0){#实际上这个条件不可能成立, 因为前面的设置使得至少有一个参数
   	return 0;
  }   
   
   my $NHDmin;
   my $NHDmax;
   my $NHD = NHD($sParameterTypeMethodMatrix);
   my $sSNHD;
   
   
   my $noRow = @{$sParameterTypeMethodMatrix};
   my $noCol = @{$sParameterTypeMethodMatrix->[0]};
      
   my $sum = 0;
   for (my $i = 0; $i < $noRow; $i++){
   	for (my $j = 0; $j < $noCol; $j++){
   		$sum = $sum + 1 if ($sParameterTypeMethodMatrix->[$i][$j] == 1);  		
   	}  	
   }
       
   if ($noCol == 0){    
   	$NHDmin = "Undefined";
   	$NHDmax = "Undefined";  		
    $sSNHD = "Undefined";  	   	
   }
   elsif ($noCol == 1){
   	$NHDmin = 1;
   	$NHDmax = 1;  		
    $sSNHD = 1;  	
   }
   else{
   	my $dd = int($sum / $noRow);
    my $qq = $sum % $noRow;
    my $cc = int(($sum - $noRow) / ($noCol - 1));
    my $rr = ($sum - $noRow) % ($noCol - 1);
    
   	$NHDmin = 1 - 2*($qq*($dd+1)*($noCol-$dd-1) + ($noRow-$qq)*$dd*($noCol-$dd)) / ($noRow*$noCol*($noCol-1));
   	$NHDmax = 1 - 2*(($rr+1)*($noCol-$rr-1) + ($noRow-$cc-1)*($noCol-1)) / ($noRow*$noCol*($noCol-1));  	
    if (($NHDmin == $NHDmax) && ($sum < $noRow * $noCol)){
   	  $sSNHD = 0;
    }
    elsif ($sum == $noRow * $noCol){
   	  $sSNHD = 1;
    }
    else {
   	  $sSNHD = 2 * ($NHD - $NHDmin) / ($NHDmax - $NHDmin) - 1; 	
    }  	
   }  
   
#   print "NHDmin = ", $NHDmin, "\n";
#   print "NHDmax = ", $NHDmax, "\n";

   return $sSNHD; 
} # END sub SNHD


sub SNHDs{
   #----计算SNHDs-----
   my $sParameterTypeMethodMatrix = shift;  	
   
   my $noRow = @{$sParameterTypeMethodMatrix};
   my $noCol = @{$sParameterTypeMethodMatrix->[0]};
   
   my @tempArr;
   
   for (my $i = 0; $i < $noRow; $i++){
   	 for (my $j = 0; $j < $noCol; $j++){
   	 	$tempArr[$i][$j] = $sParameterTypeMethodMatrix->[$i][$j];   	 	
   	 }   	
   }
      
   for (my $j = 0; $j < $noCol; $j++){ #给每个方法加一个相同的参数"self"
   	 $tempArr[$noRow][$j] = 1;   	
   }
   
   my $sSNHDs = SNHD(\@tempArr);  
	
	 return $sSNHDs;	
}



###############compute MI########################

# return declaration ref (based on language) or 0 if unknown
sub getDeclRef 
{
    my ($ent) =@_;
    my $decl;
    return $decl unless defined ($ent);
    
   ($decl) = $ent->refs("definein","",1);
	 ($decl) = $ent->refs("declarein","",1) unless ($decl);

    return $decl;
} # END sub getDeclRef


# scan the code in the specified range of lines
# and return the 4 basic operator/operand metrics
sub scanEntity
{
  my ($lexer, $startline, $endline) = @_;
  my $n1=0;
  my $n2=0;
  my $N1=0;
  my $N2=0;
  
  my %n1 = ();
  my %n2 = ();


  foreach my $lexeme ($lexer->lexemes($startline,$endline)) 
  {

     if (($lexeme->token eq "Operator") || ($lexeme->token eq "Keyword") || ($lexeme->token eq "Punctuation"))
     {  
        
        if ($lexeme->text() !~ /[)}\]]/)
        {
           $n1{$lexeme->text()} = 1;

#           print "\t  n1--->", $lexeme->text(), "\n";

           $N1++;
        }
     }
     elsif (($lexeme->token eq "Identifier") || ($lexeme->token eq "Literal") || ($lexeme->token eq "String"))
     {
        $n2{$lexeme->text()} = 1;

#        print "\t  n2--->", $lexeme->text(), "\n";

        $N2++;
     }
  }
  
  $n1 = scalar( keys(%n1));
  $n2 = scalar( keys(%n2));  
   
  return ($n1,$n2,$N1,$N2);
} # End sub scanEntity





# return array of functions in a file
sub getFuncs {
    my $db = shift;
    my $file = shift;
    my $lexer = shift;
    my $language = $db->language();   # use language of $file when available
    my @funcs = ();

    my $refkind;
    my $entkind;
    if ($language =~ /ada/i) {
	$refkind = "declarein body";
	$entkind = "function,procedure";
    } elsif ($language =~ /java/i) {
	$refkind = "definein";
	$entkind = "method";
    } elsif ($language =~ /c/i) {
	$refkind = "definein";
	$entkind = "function";
    } else {
	return ();
    }

    $lexer = $file->lexer() if !$lexer;
    foreach my $lexeme ($lexer->lexemes()) {
	next if !$lexeme;
	my $ref = $lexeme->ref();
	my $ent = $lexeme->entity();
	if ($ref && $ent && $ref->kind->check($refkind) && $ent->kind->check($entkind)) {
	    push @funcs, $ent;
	}
    }
    return @funcs;
} # END sub getFuncs



sub isCPlusPlusConstructor{
	my $class = shift;
	my $method = shift;	
	
	if ($class->name() eq $method->name()){
#		print "Consructor: ", $method->name(), "  ",$method->id(), " \n";
		return 1;
	}	
	return 0;
} # END sub isCPlusPlusConstructor


sub isCPlusPlusDestructor{
	my $class = shift;
	my $method = shift;
	if ("~".$class->name() eq $method->name()){
#		print "Desructor: ", $method->name(), "  ",$method->id(), " \n";
		return 1;	
	}
	return 0;
} # END sub isCPlusPlusDestructor


sub isCPlusPlusAccessOrDelegationMethod{
	my $class = shift;
	my $method = shift;
	
#	print "Yes, I am here!\n";
	
	my %readList = ();
	foreach my $attribute ($method->ents("Use","Member Object ~unknown ~unresolved, Member Variable ~unknown ~unresolved")){
		$readList{$attribute->id()} = 1;
	}
	
	my %writeList = ();
	foreach my $attribute ($method->ents("Set","Member Object ~unknown ~unresolved, Member Variable ~unknown ~unresolved")){
		$writeList{$attribute->id()} = 1;
	}
	
	my %modifyList = ();
	foreach my $attribute ($method->ents("Modify","Member Object ~unknown ~unresolved, Member Variable ~unknown ~unresolved")){
		$modifyList{$attribute->id()} = 1
	}
	
	my %allAttributeList = ();
	foreach my $key (keys %readList){
		$allAttributeList{$key} = 1;
	}

	foreach my $key (keys %writeList){
		$allAttributeList{$key} = 1;
	}

	foreach my $key (keys %modifyList){
		$allAttributeList{$key} = 1;
	}
	
	my $noModifyAttribute = scalar (keys %modifyList);
	my $noAllAccessAttribute = scalar (keys %allAttributeList);
	my $noStatements = $method->metric("CountStmt");	

	my @callList = $method->ents("Call ~inactive, use ptr ~inactive","function,  method");	
	my $noCalls = @callList;  

#	print $method->name(), "  ",$method->id(), " \n";
#	print "\t\t noStatements = ", $noStatements, "\n";
#	print "\t\t noAllAccessAttribute = ", $noAllAccessAttribute, " \n";	

	if ($noStatements == 1 && $noAllAccessAttribute ==1){
		if ($noCalls){
#   		print "Delegation method: ", $method->name(), "  ",$method->id(), " \n";
    	return 1;  						
		}
# 		print "Access method: ", $method->name(), "  ",$method->id(), " \n";
   	return 1;  					
	}
  
  return 0;   	
} # END sub isCPlusPlusAccessOrDelegationMethod


sub isJavaConstructor{
	my $class = shift;
	my $method = shift;
	my @className = split /\./, $class->name();
	my @methodName = split /\./, $method->name();
	
	if ($className[$#className] eq $methodName[$#methodName]){	
#		print $class->name(), "<============>",$method->name(), " \n";
		
		return 1;
	}
	return 0;	
} # END sub isJavaConstructor


sub isJavaDestructor{

} # END sub isJavaDestructor


sub isJavaAccessOrDelegationMethod{
	my $class = shift;
	my $method = shift;  
  
	my %readList = ();
	foreach my $attribute ($method->ents("Use","Member Object ~unknown ~unresolved, Member Variable ~unknown ~unresolved")){
		$readList{$attribute->id()} = 1;
	}
	
	my %writeList = ();
	foreach my $attribute ($method->ents("Set","Member Object ~unknown ~unresolved, Member Variable ~unknown ~unresolved")){
		$writeList{$attribute->id()} = 1;
	}
	
	my %modifyList = ();
	foreach my $attribute ($method->ents("Modify","Member Object ~unknown ~unresolved, Member Variable ~unknown ~unresolved")){
		$modifyList{$attribute->id()} = 1
	}
	
	my %allAttributeList = ();
	foreach my $key (keys %readList){
		$allAttributeList{$key} = 1;
	}

	foreach my $key (keys %writeList){
		$allAttributeList{$key} = 1;
	}

	foreach my $key (keys %modifyList){
		$allAttributeList{$key} = 1;
	}
	
	my $noModifyAttribute = scalar (keys %modifyList);
	my $noAllAccessAttribute = scalar (keys %allAttributeList);
	my $noStatements = $method->metric("CountStmt");	

#	$CountLineCode = $class->metric("CountLineCode");
#	
#	$CountLineExe = $class->metric("CountLineExe");


	my @callList = $method->ents("Call ~inactive, use ptr ~inactive","function,  method");	
	my $noCalls = @callList;  
	
#	print $method->name(), "  ",$method->id(), " \n";
#	print "\t\t noStatements = ", $noStatements, "\n";
#	print "\t\t noAllAccessAttribute = ", $noAllAccessAttribute, " \n";

	if ($noStatements == 2 && $noAllAccessAttribute ==1){  #Java的语句计算方式与C++有细微的差别, 所以用2
		if ($noCalls){
#   		print "Delegation method: ", $method->name(), "  ",$method->id(), " \n";
    	return 1;  						
		}
# 		print "Access method: ", $method->name(), "  ",$method->id(), " \n";
   	return 1;  					
	}
  
  return 0;   	
} # END sub isJavaAccessOrDelegationMethod


sub hashTable2Matrix{
	 #注意: 第一个参数带出方法的编号信息
	 #后面的每个参数是一个哈希表的引用
	 #      返回值是一个行表示属性(参数),列表示方法, 值代表访问关系的矩阵
	 
#   print "-----From hashTable2Matrix--------\n";	 
	 
	 	 	 
	 my $sNoForMethod = shift(@_);

   #很重要,保证清空	 
	 foreach my $key (sort keys %{$sNoForMethod}){
	  	delete $sNoForMethod->{$key};
	 }	 
	
	 
   my %hashTable = ();
   
   #将多个哈希表合并成一个哈希表hashTable
   foreach my $aHashRef (@_){   	 
   	foreach my $attributeKey (sort keys %{$aHashRef}){
   		my %tempMethodHashTable = %{$aHashRef->{$attributeKey}};
   		foreach my $methodKey (sort keys %tempMethodHashTable){
   			$hashTable{$attributeKey}->{$methodKey} = 1;
   		}
   	}	
   }
   
   my $NumOfRow = 0;
   my $NumOfColumn = 0;


   #计算矩阵的行数 
   my @tempArr;
   @tempArr = (keys %hashTable);
   $NumOfRow = @tempArr;

   #判断是否有key为"withoutParameterAndAttribute"的项存在: 这些方法不访问任何属性(参数)   
   if (exists $hashTable{"withoutParameterAndAttribute"}){
    	$NumOfRow = $NumOfRow - 1;
   }
     
#   print "NumOfRow: ", $NumOfRow, "\n";
      
   #计算矩阵的列数  
   
   foreach my $attributeKey (sort keys %hashTable){
   	my %tempMethodHashTable = %{$hashTable{$attributeKey}};
   	foreach my $methodKey (sort keys %tempMethodHashTable){
   		next if ($methodKey eq "withoutMethodAccess");
   		$sNoForMethod->{$methodKey} = 1;   		
   	}
   }
   
   
  
   
   #给每个方法编号
   my $jj=0;
   foreach my $method (sort keys %{$sNoForMethod}){
   	$sNoForMethod->{$method} = $jj;
   	$jj++;  	
   } 
   
      
   @tempArr = (keys %{$sNoForMethod});
   $NumOfColumn = @tempArr;
#   print "NumOfColumn: ", $NumOfColumn, "\n";
   
   
   #建立矩阵
   my @outputMatrix;
   
   for (my $i = 0; $i < $NumOfRow; $i++)   {
   	for (my $j = 0; $j < $NumOfColumn; $j++){
   		$outputMatrix[$i][$j] = 0;   	
    }
   }
   
   my $i = 0;
   foreach my $attributeKey (sort keys %hashTable)  {
   	    next if ($attributeKey eq "withoutParameterAndAttribute");
   	    my %tempMethodHashTable = %{$hashTable{$attributeKey}};
   	    foreach my $methodKey (sort keys %tempMethodHashTable){
   	    	#跳过"withoutMethodAccess", 它并不是一个方法名, 只是用来表示对应的属性(参数)没有任何方法访问
   	    	next if ($methodKey eq "withoutMethodAccess");
   	    	$outputMatrix[$i][$sNoForMethod->{$methodKey}] = 1;    	  
   	    }
    	  $i++;  	  
   }
   
 
   return wantarray?(\@outputMatrix, $NumOfRow, $NumOfColumn): \@outputMatrix;
} # END sub hashTable2Matrix


	
sub generateMethodMethodMatrix{
	#参数:属性-方法矩阵
	#返回值: 方法-方法矩阵, 实际上是方法相似矩阵
	
	my $inputMatrix = shift;	
	my $sNoForMethods = shift; #方法的编号hash表
	my $includeMethodCall = shift; #结果矩阵中是否包含被调用关系
	                               #值为1时,表示直接的被调用关系
	                               #值为2时,表示间接的被调用关系  
	my $sMethodCallBySet = shift; #被调用关系集合
	
	my @outputMatrix;
	
	#如果类中没有属性, 则建立所有值都为0的方法矩阵
	if (@{$inputMatrix} == 0){		
		my $noRow = scalar (keys %{$sNoForMethods});
		my $noCol = $noRow;
		
		for (my $i = 0; $i < $noRow; $i++){
			for (my $j = 0; $j < $noCol; $j++){
				$outputMatrix[$i][$j] = 0;
			}
		}
		
		if ($includeMethodCall == 1){
			foreach my $fstKey (sort keys %{$sMethodCallBySet}){
				next if (!exists $sNoForMethods->{$fstKey});
				foreach my $sndKey (sort keys %{$sMethodCallBySet->{$fstKey}}){
					next if (!exists $sNoForMethods->{$sndKey});
					$outputMatrix[$sNoForMethods->{$fstKey}][$sNoForMethods->{$sndKey}] = 1;
					$outputMatrix[$sNoForMethods->{$sndKey}][$sNoForMethods->{$fstKey}] = 1;					
				}
			}			
		}	
		
		if ($includeMethodCall == 2){
			foreach my $fstKey (sort keys %{$sMethodCallBySet}){
				my @methodArray = (sort keys %{$sMethodCallBySet->{$fstKey}});
				for (my $i = 0; $i < @methodArray - 1; $i++){
					next if (!exists $sNoForMethods->{$methodArray[$i]});
					for (my $j = $i + 1; $j < @methodArray; $j++){
						next if (!exists $sNoForMethods->{$methodArray[$j]});
						$outputMatrix[$sNoForMethods->{$methodArray[$i]}][$sNoForMethods->{$methodArray[$j]}] = 1;
						$outputMatrix[$sNoForMethods->{$methodArray[$j]}][$sNoForMethods->{$methodArray[$i]}] = 1;						
					}
				}
			}			
		}
				
		return @outputMatrix;		
	}
			
	my $noRowOrColumn = @{$inputMatrix->[0]};
	
	for (my $i = 0; $i < $noRowOrColumn; $i++){
		for (my $j = 0; $j < $noRowOrColumn; $j++){
			$outputMatrix[$i][$j] = 0;
		}
	}
	
	for (my $i = 0; $i < $noRowOrColumn - 1; $i++){
		for (my $j = $i + 1; $j < $noRowOrColumn; $j++){
			
			my @arrayOne; 		
			my @arrayTwo;
			for (my $k = 0; $k < @{$inputMatrix}; $k++){
				$arrayOne[$k] = $inputMatrix->[$k][$i];
				$arrayTwo[$k] = $inputMatrix->[$k][$j];
			}
			
			if (isMethodSimilar(\@arrayOne, \@arrayTwo)){
				$outputMatrix[$i][$j] = 1;
				$outputMatrix[$j][$i] = 1;
			}			
		}		
	}
	
	if ($includeMethodCall == 1){
		foreach my $fstKey (sort keys %{$sMethodCallBySet}){
			next if (!exists $sNoForMethods->{$fstKey});				
			foreach my $sndKey (sort keys %{$sMethodCallBySet->{$fstKey}}){
				next if (!exists $sNoForMethods->{$sndKey});
				$outputMatrix[$sNoForMethods->{$fstKey}][$sNoForMethods->{$sndKey}] = 1;
				$outputMatrix[$sNoForMethods->{$sndKey}][$sNoForMethods->{$fstKey}] = 1;					
			}
		}			
	}	
	
	if ($includeMethodCall == 2){
			foreach my $fstKey (sort keys %{$sMethodCallBySet}){
				my @methodArray = (sort keys %{$sMethodCallBySet->{$fstKey}});
				for (my $i = 0; $i < @methodArray - 1; $i++){
					next if (!exists $sNoForMethods->{$methodArray[$i]});
					for (my $j = $i + 1; $j < @methodArray; $j++){
						next if (!exists $sNoForMethods->{$methodArray[$j]});
						$outputMatrix[$sNoForMethods->{$methodArray[$i]}][$sNoForMethods->{$methodArray[$j]}] = 1;
						$outputMatrix[$sNoForMethods->{$methodArray[$j]}][$sNoForMethods->{$methodArray[$i]}] = 1;						
				}
			}
		}			
	}
		
  return @outputMatrix;
} # END sub generateMethodMethodMatrix



sub depthFirstSearch{
	#参数1:方法相似性矩阵
	#参数2:起始顶点
	#参数3:标记矩阵
	#处理:直接修改标记矩阵
  
  my $aTwoDimArray = shift;
  my $node = shift; 
  my $visited = shift;
  my $noElem = shift;
  
  $visited->[$node] = 1;
    
  for (my $i = 0; $i < @{$aTwoDimArray}; $i++){
  	if (($aTwoDimArray->[$node][$i] == 1) && !$visited->[$i]){
  		depthFirstSearch($aTwoDimArray, $i, $visited);		
  	}
  }  
} # END sub depthFirstSearch




sub buildParameterHashTable{
	my $class = shift; #类
	my $excludePrivateProtectedMethods = shift; #是否排除"私有"或者"受保护"方法
	my $excludeConstructorAndDestructor = shift; #是否排除"构造函数和析构函数"
	my $excludeAccessAndDelegationMethod = shift; #是否排除"访问方法和代理方法"
	my $includeFunctionType = shift; #在计算函数的参数类型时是否包括函数的返回值类型
	my $sParaTable = shift;


  my @methodArray = ();
  
  if (!$excludePrivateProtectedMethods){
  	@methodArray = getRefsInClass($class, "define","function ~unknown,  method ~unknown");
  }
  else{
  	@methodArray = getRefsInClass($class, "define","function ~private ~protected ~unknown, method ~private ~protected ~unknown");
  }
  
  if (@methodArray == 0){
  	return 0; 	
  }
  

  #某些hash表清空
  foreach my $key (sort keys %{$sParaTable}){
  	delete $sParaTable->{$key};
  }
  

	#处理部分
  foreach my $method (@methodArray){
	  my $func = $method->ent();
	  
 	  if ($excludeConstructorAndDestructor){
	  	next if $isConstructor->($class, $func);
	  	next if $isDestructor->($class, $func);
	  }	  

 	  if ($excludeAccessAndDelegationMethod){
# 	  	print "hallo!\n";
	  	next if $isAccessOrDelegationMethod->($class, $func);
	  }	  

	  
	  my @paraArray = $func->ents("Define","Parameter");
	  
	  if ($includeFunctionType && $func->type() && ($func->type() ne "void")){	  
	  	push @paraArray, $func; 
	  }
  
    if (@paraArray == 0){
	  	$sParaTable->{"withoutParameterAndAttribute"}->{$func->id()} = 1;
	  }
	  else{
	  	foreach my $param (@paraArray)  {  
    	  $sParaTable->{$param->type()}->{$func->id()} = 1;    	  
    	 } 
    }   
    
} #foreach $func
	
#排除特殊方法后, 有可能没有任何方法    
 if (scalar (keys %{$sParaTable}) == 0){
  	return 0;
 }	    
	    
return 1;		
} # END sub buildParameterHashTable
	
	

sub buildAttributeHashTables{
	my $class = shift; #类
	my $excludePrivateProtectedMethods = shift; #是否排除"私有"或者"受保护"方法
	my $excludeConstructorAndDestructor = shift; #是否排除"构造函数和析构函数"
	my $excludeAccessAndDelegationMethod = shift; #是否排除"访问方法和代理方法"
	my $includeIndirectAccess = shift; #是否包括方法和属性间的"间接访问"关系
	my $sAttributeReadTable = shift;
	my $sAttributeWriteTable = shift;
	my $sAttributeModifyTable = shift;
	my $sMethodWithoutAttributeParaTable = shift; #只有一个key(即withoutParameterAndAttribute)的哈希表, 值为没有参数或者属性访问的方法
	my $sAttributeWithoutAccessTable = shift; #对应每个key, 值为"withoutMethodAccess". 表示该属性没有任何方法访问
	my $sDirectCallByMethodSet = shift; #直接被调用的方法集


  my @methodArray = ();
  @methodArray = getRefsInClass($class, "define","function ~unknown ~unresolved,  method ~unknown ~unresolved");
#  print "\n", "methodArray = ", scalar @methodArray, "\n";
  
  if (@methodArray == 0){
  	return 0; 	
  }
    
  my %classMethodTable = ();
  for (my $i = 0; $i < @methodArray; $i++){
   	$classMethodTable{$methodArray[$i]->ent()->id()} = 1;
  }
  
 
  my %classAttributeTable = ();  
  my @classAttributes = getRefsInClass($class, "define","Member Object ~unknown ~unresolved, Member Variable ~unknown ~unresolved");  
  for (my $i = 0; $i < @classAttributes; $i++){
   	$classAttributeTable{$classAttributes[$i]->ent()->id()} = 1;
  }


  foreach my $key (sort keys %{$sAttributeReadTable}){
  	delete $sAttributeReadTable->{$key};
  }
  
  foreach my $key (sort keys %{$sAttributeWriteTable}){
  	delete $sAttributeWriteTable->{$key};
  }
	
  foreach my $key (sort keys %{$sAttributeModifyTable}){
  	delete $sAttributeModifyTable->{$key};
  }
	
  foreach my $key (sort keys %{$sMethodWithoutAttributeParaTable}){
  	delete $sMethodWithoutAttributeParaTable->{$key};
  }

  foreach my $key (sort keys %{$sAttributeWithoutAccessTable}){
  	delete $sAttributeWithoutAccessTable->{$key};
  }

  foreach my $key (sort keys %{$sDirectCallByMethodSet}){
  	delete $sDirectCallByMethodSet->{$key};
  }  


  foreach my $method (@methodArray){
#	  print "**********method = ", $func->name(), "***********\n";
	  my $func = $method->ent();
	  
 	  if ($excludeConstructorAndDestructor){ 	  	
	  	next if $isConstructor->($class, $func);
	  	next if $isDestructor->($class, $func);
	  }	  

 	  if ($excludeAccessAndDelegationMethod){
	  	next if $isAccessOrDelegationMethod->($class, $func);
	  }	  



	  my @callMethodSet = $func->ents("Call ~inactive, use ptr ~inactive","function ~unknown ~unresolved,  method ~unknown ~unresolved");	  
	  foreach my $tempMethod (@callMethodSet){
	  	next if (!exists $classMethodTable{$tempMethod->id()});	  	  	
	  	$sDirectCallByMethodSet->{$tempMethod->id()}->{$func->id()} = 1;	    
	  }
	}
	
	  
	my %tempInDirectCallByMethodSet = getIndirectCallByMethodSet($sDirectCallByMethodSet);   


	#处理部分
  foreach my $method (@methodArray){
	  my $func = $method->ent();
#	  print "**********method = ", $func->name(), "***********\n";	  
 	  if ($excludeConstructorAndDestructor){
	  	next if $isConstructor->($class, $func);
	  	next if $isDestructor->($class, $func);
	  }	  

 	  if ($excludeAccessAndDelegationMethod){
	  	next if $isAccessOrDelegationMethod->($class, $func);
	  }	  
	  
	  
	  
	  
#	  my $refObjects = $func->ref()->file()->lexer();
#	  
#	  my ($startref) = $func->refs("definein", "", 1);
#	  my ($endref) = $func->refs("end", "", 1);
#	  
#	  my @tokenArray = $refObjects->lexemes($startref->line(), $endref->line());
#	  if (!@tokenArray){
#	  	print "has no tokens \n";
#	  }
#	  foreach my $refO (@tokenArray) {
#	  	print "token = ", $refO->token(), "\t text = ", $refO->text();
#	  	if (defined($refO->ent())){
#	  		print "\t ent type = ", $refO->ent()->type();
#	  	}
#	  	print "\n";	  	
#	  }
	  
	  
	  
#	  print "\n\n";
	  
  
  	foreach my $attribute ($func->ents("Use","Member Object ~unknown ~unresolved ~Local, Member Variable ~unknown ~unresolved ~Local"))  {
  		  next if (!exists $classAttributeTable{$attribute->id()}); 
        $sAttributeReadTable->{$attribute->id()}->{$func->id()} = 1;
        
        if ($includeIndirectAccess && exists $tempInDirectCallByMethodSet{$func->id()}){
        	foreach my $methodKey (sort keys %{$tempInDirectCallByMethodSet{$func->id()}}){
        		$sAttributeReadTable->{$attribute->id()}->{$methodKey} = 1;        		
        	}         	
        }        
      #  print "Reading Attribute====>", $attribute->longname(), ":::::::", $attribute->kindname(), "\n";
     }
    
    
    
    
    foreach my $attribute ($func->ents("Modify","Member Object ~unknown ~unresolved ~Local, Member Variable ~unknown ~unresolved ~Local"))  {
    	  next if (!exists $classAttributeTable{$attribute->id()});
        $sAttributeModifyTable->{$attribute->id()}->{$func->id()} = 1;
        
        if ($includeIndirectAccess && exists $tempInDirectCallByMethodSet{$func->id()}){
        	foreach my $methodKey (sort keys %{$tempInDirectCallByMethodSet{$func->id()}}){
        		$sAttributeModifyTable->{$attribute->id()}->{$methodKey} = 1;        		
        	}         	
        } 
#       print "Modifying Attribute====>", $attribute->name(),  ":::::::", $attribute->kindname(), "\n";
    }
    

    foreach my $attribute ($func->ents("Set","Member Object ~unknown ~unresolved ~Local, Member Variable ~unknown ~unresolved ~Local"))  {
    	  next if (!exists $classAttributeTable{$attribute->id()});
        $sAttributeWriteTable->{$attribute->id()}->{$func->id()} = 1;
        
        if ($includeIndirectAccess && exists $tempInDirectCallByMethodSet{$func->id()}){
        	foreach my $methodKey (sort keys %{$tempInDirectCallByMethodSet{$func->id()}}){
        		$sAttributeWriteTable->{$attribute->id()}->{$methodKey} = 1;        		
        	}         	
        }         
#        print "Writing Attribute====>", $attribute->name(),  ":::::::", $attribute->kindname(), "\n";
    }
    
#    print "\n\n";
} #foreach $func


   if ($excludePrivateProtectedMethods){  
   	my @tempMethodArray = getRefsInClass($class, "define","function ~private ~protected ~unknown ~unresolved, method ~private ~protected ~unknown ~unresolved");
   	
   	my @pubMethodArray = ();
   	for (my $i = 0; $i < @tempMethodArray; $i++){
   		$pubMethodArray[$i] = $tempMethodArray[$i]->ent()->id();
   	}
   	
   	includeOnlyElements($sAttributeReadTable, \@pubMethodArray);
   	includeOnlyElements($sAttributeWriteTable, \@pubMethodArray);
   	includeOnlyElements($sAttributeModifyTable, \@pubMethodArray);   
   }


    #收集没有访问任何属性的方法
    my %tempMethodHashTable;
    
    foreach my $method (@methodArray){    	  
	     foreach my $fstKey (keys %{$sAttributeReadTable}){
	      foreach my $sndKey (keys %{$sAttributeReadTable->{$fstKey}}){
	     		$tempMethodHashTable{$sndKey} = 1;
	     	}
       }

	     foreach my $fstKey (keys %{$sAttributeWriteTable}){
	  	   foreach my $sndKey (keys %{$sAttributeWriteTable->{$fstKey}}){
	  		   $tempMethodHashTable{$sndKey} = 1;
	  	   }
       }
    
	     foreach my $fstKey (keys %{$sAttributeModifyTable}){
	  	   foreach my $sndKey (keys %{$sAttributeModifyTable->{$fstKey}}){
	  		   $tempMethodHashTable{$sndKey} = 1;
	  	   }
       }
    }
    
    foreach my $method (@methodArray){
    	my $func = $method->ent();
    	
 	  if ($excludeConstructorAndDestructor){
	  	next if $isConstructor->($class, $func);
	  	next if $isDestructor->($class, $func);
	  }	  

 	  if ($excludeAccessAndDelegationMethod){
	  	next if $isAccessOrDelegationMethod->($class, $func);
	  }	  
  
    	    
    	if (!exists $tempMethodHashTable{$method}){
    		$sMethodWithoutAttributeParaTable->{"withoutParameterAndAttribute"}->{$func->id()} = 1;    		
    	}   	
    }
    
    if ($excludePrivateProtectedMethods){ 
    	my @tempMethodArray = getRefsInClass($class, "define","function ~private ~protected ~unknown ~unresolved, method ~private ~protected ~unknown ~unresolved");
   	
   	  my @pubMethodArray = ();
   	  for (my $i = 0; $i < @tempMethodArray; $i++){
   		  $pubMethodArray[$i] = $tempMethodArray[$i]->ent()->id();
   	  }
   	
   	  includeOnlyElements($sMethodWithoutAttributeParaTable, \@pubMethodArray);   	
    }

  
  
    
    #收集没有被任何方法访问的属性

    my %aTempHashTable;
    
    foreach my $key (keys %{$sAttributeReadTable}){
    	$aTempHashTable{$key} = 1;
    }

    foreach my $key (keys %{$sAttributeWriteTable}){
    	$aTempHashTable{$key} = 1;
    }

    foreach my $key (keys %{$sAttributeModifyTable}){
    	$aTempHashTable{$key} = 1;
    }

    foreach my $key (sort keys %classAttributeTable){
    	if (!$aTempHashTable{$key}){
    		$sAttributeWithoutAccessTable->{$key}->{"withoutMethodAccess"} = 1;
    	}
    }
    
    my @WithoutAccess = (keys %{$sAttributeWithoutAccessTable});    
    
    if (@WithoutAccess){
#    	print "no of attributes without access =====>", scalar @WithoutAccess, "\n";
    }
  




    my %tempInDirectCallByMethodSet = getIndirectCallByMethodSet($sDirectCallByMethodSet); 


#    print "=========Direct calls==============\n";
#	  foreach my $inKey (sort keys %{$sDirectCallByMethodSet}){
#	  	print $inKey, " calls : \n";
#	  	foreach my $calledKey (sort keys %{$sDirectCallByMethodSet->{$inKey}}){
#	  		print "\t\t", $calledKey, "\n";	  		
#	  	}
#	  }
#
#    print "=========Indirect calls==============\n";
#	  foreach my $inKey (sort keys %tempInDirectCallByMethodSet){
#	  	print $inKey, " calls : \n";
#	  	foreach my $calledKey (sort keys %{$tempInDirectCallByMethodSet{$inKey}}){
#	  		print "\t\t", $calledKey, "\n";	  		
#	  	}
#	  }
# 

	return 1;	
} # END sub buildAttributeHashTables


sub includeOnlyElements{
	#第一个参数是2维hash表, 第二个参数是一个数组;
	#功能: 将非第二个参数中的内容(字符)从第一个参数中删除(第2维中的key)
	
	my $sHashTable = shift;
	my $sElementArray = shift;	
	
	my %bakHashTable = ();
	
	foreach my $fstKey (sort keys %{$sHashTable}){
		my %sndHashTable = %{$sHashTable->{$fstKey}};
		
		for (my $i = 0; $i < @{$sElementArray}; $i++){
			next if (!exists $sndHashTable{$sElementArray->[$i]});
			$bakHashTable{$fstKey}->{$sElementArray->[$i]} = 1;		
		}		
	}		
		
	foreach my $key (sort keys %{$sHashTable}){
		delete $sHashTable->{$key};
	}
	
	foreach my $fstKey (sort keys %bakHashTable){
		foreach my $sndKey (sort keys %{$bakHashTable{$fstKey}}){
			$sHashTable->{$fstKey}->{$sndKey} = 1;
		}
	}
	
	return;
}


sub getIndirectCallByMethodSet{
	my $sDirectCallByMethodSet = shift;
	my %InDirectCallByMethodSet = ();
	
	my %visited;
	
	foreach my $fstKey (sort keys %{$sDirectCallByMethodSet}){
		$visited{$fstKey} = 0;
		my %aMethodHashTable = %{$sDirectCallByMethodSet->{$fstKey}};
		foreach my $sndKey (sort keys %aMethodHashTable) {
			$visited{$sndKey} = 0;
		}
	}
	
	
	my $i = 0;
	foreach my $fstKey (sort keys %{$sDirectCallByMethodSet}){
		my %aMethodHashTable = %{$sDirectCallByMethodSet->{$fstKey}};
		
		my @aStack = (sort keys %aMethodHashTable);
		
		foreach my $vstKey (sort keys %visited){
			$visited{$vstKey} = 0;
		}		
		$visited{$fstKey} = 1;
				
		while (@aStack > 0){
			my $elem = shift(@aStack);
			$InDirectCallByMethodSet{$fstKey}->{$elem} = 1;
			$visited{$elem} = 1;
			
			#下面这句非常重要
			next if (!exists $sDirectCallByMethodSet->{$elem});
			
			foreach my $key (sort keys %{$sDirectCallByMethodSet->{$elem}}){
				if (!$visited{$key}){				
					push @aStack, $key;
				}
			}			
		}	
	}
		
	return %InDirectCallByMethodSet;
} # END sub getIndirectCallByMethodSet

	
sub openDatabase($)
{
    my ($dbPath) = @_;
    
    my $db = Understand::Gui::db();

    # path not allowed if opened by understand
    if ($db&&$dbPath) {
	die "database already opened by GUI, don't use -db option\n";
    }

    # open database if not already open
    if (!$db) {
	my $status;
	die usage("Error, database not specified\n\n") unless ($dbPath);
	($db,$status)=Understand::open($dbPath);
	die "Error opening database: ",$status,"\n" if $status;
    }
    return($db);
}


sub closeDatabase($)
{
    my ($db)=@_;

    # close database only if we opened it
    $db->close() if (!Understand::Gui::active());
}


sub getLastName{
	my $completeName = shift;
	
	my @wordList = split /\./, $completeName;
	
	return $wordList[$#wordList];	
}


sub getClassKey{
	my $sClass = shift;
	
	my $result = $sClass->ref()->file()->relname()."-->".getLastName($sClass->name());
	
	return $result;	
}#END sub getClassKey


sub getAncestorClasses{
	my $sClass = shift;
	my $sAncestorClassHash = shift;
	
	my $sAncestorClassLevel = {}; #祖先类相对于当前类的层次, 直接父亲的层次为1, 直接爷爷的层次为2, ...
	
	#计算祖先类的集合
	my @parentList;
	
	foreach my $parent ($sClass->refs("Base, Extend", "class", 1)){
		my $pair = {};
		$pair->{classEnt} = $parent->ent();
		$pair->{level} = 1;
		push @parentList, $pair;		
	}	
		
	while (@parentList > 0){		
		my $parentPair = shift @parentList;
		
		my $parentClassEnt = $parentPair->{classEnt};
		my $parentLevel = $parentPair->{level};
		
		my $parentClassKey = getClassKey($parentClassEnt);
		next if (exists $sAncestorClassHash->{$parentClassKey}); #防止死循环
		   
		$sAncestorClassHash->{$parentClassKey} = $parentClassEnt;
		$sAncestorClassLevel->{$parentLevel}->{$parentClassKey} = 1;
		
		foreach my $parent ($parentClassEnt->refs("Base, Extend", "class", 1)){
			my $pair = {};
		  $pair->{classEnt} = $parent->ent();
		  $pair->{level} = $parentLevel + 1;			
			push @parentList, $pair;
		}
	}
	
	return $sAncestorClassLevel;
}#END sub getAncestorClasses



sub getDescendentClasses{
	my $sClass = shift;
	my $sDescendentClassHash = shift;

#  print "\t\t\t computing getDescendentClasses..." if ($debug);
  	
	my @sonList;
	
	foreach my $son ($sClass->refs("Derive, Extendby", "class", 1)){
		push @sonList, $son->ent();		
	}			

	while (@sonList > 0){		
		my $currentSon = shift @sonList;
		
		my $sonClassKey = getClassKey($currentSon);
		next if (exists $sDescendentClassHash->{$sonClassKey}); #防止死循环
		
		$sDescendentClassHash->{$sonClassKey} = $currentSon;
		foreach my $son ($currentSon->refs("Derive, Extendby", "class", 1)){
			push @sonList, $son->ent();
		}
	}
	
#	print "....getDescendentClasses END\n" if ($debug);
	
	return 1;
}#END sub getDescendentClasses


sub getFriendClasses{
	my $sClass = shift;
	my $sFriendClassHash = shift;
	
	return if ($sClass->language() !~ m/c/i);
	
	foreach my $friend ($sClass->ents("Friend", "Class")){
		my $friendClassKey = getClassKey($friend);
		$sFriendClassHash->{$friendClassKey} = $friend;
	}
	
	return 1;
}#END sub getFriendClasses


sub getInverseFriendClasses{
	my $sClass = shift;
	my $sInverseFriendClassHash = shift;
	
	return if ($sClass->language() !~ m/c/i);
	
	foreach my $friendby ($sClass->ents("Friendby", "Class")){
		my $inverseFriendClassKey = getClassKey($friendby);
		$sInverseFriendClassHash->{$inverseFriendClassKey} = $friendby;
	}
	
	return 1;	
}#END sub getInverseFriendClasses



#此处otherClassHash为祖先类、后裔类、友元类、逆向友元类和自身的并的结果
sub getOtherClasses{
	my $sClass = shift;
	my $sAllClassNameHash = shift;	
	my $sAncestorClassHash = shift;
	my $sDescendentClassHash = shift;	
	my $sFriendClassHash = shift;
	my $sInverseFriendClassHash = shift;
	my $sOtherClassHash = shift;
	
	my $currentClassKey = getClassKey($sClass); 
	$sOtherClassHash->{$currentClassKey} = $sClass;
	
	foreach my $classKey (keys %{$sAncestorClassHash}){		
		$sOtherClassHash->{$classKey} = $sAncestorClassHash->{$classKey};
	}
	
	foreach my $classKey (keys %{$sDescendentClassHash}){		
		$sOtherClassHash->{$classKey} = $sDescendentClassHash->{$classKey};
	}
	
	foreach my $classKey (keys %{$sFriendClassHash}){		
		$sOtherClassHash->{$classKey} = $sFriendClassHash->{$classKey};
	}

	foreach my $classKey (keys %{$sInverseFriendClassHash}){		
		$sOtherClassHash->{$classKey} = $sInverseFriendClassHash->{$classKey};
	}
	
	return 1;
}#END sub getOtherClasses


sub getAddedMethods{
#返回给定类中新增添的方法(非继承/非override的方法)
  my $sClass = shift;
  my $sAddedMethodHash = shift; 
  
  my %ancestorHash;	#之所以用Hash表, 考虑多继承的情况
  getAncestorClasses($sClass, \%ancestorHash);
	
	my %methodInAncestor; # 祖先类中的方法集
	
	foreach my $key (keys %ancestorHash){
		my $ancestorClass = $ancestorHash{$key};
		
		my @funcList = getEntsInClass($ancestorClass, "Define", "Function ~private,Method ~private");
		
		foreach my $func (@funcList){
			my $signature = getFuncSignature($func, 1);
			$methodInAncestor{$signature} = 1;
		}
	}
	
	my @currentFuncList = getEntsInClass($sClass, "Define", "Function, Method");
	
	foreach my $func (@currentFuncList){
		my $currentSignature = getFuncSignature($func, 1);
		
		next if (exists $methodInAncestor{$currentSignature});
		
		$sAddedMethodHash->{getFuncSignature($func, 1)} = $func;
	}
	
	return 1;	
}#END sub getInheritedMethods


sub getNoOfClassAttributeInteraction{
#给定类c和d, 返回从c到d的类-属性交互数目, 也就是类c中以d为类型的属性数目
  my $sClassC = shift;
  my $sClassD = shift;
  
	my @attributeArray = $sClassC->refs("define","Member Object ~unknown ~unresolved, Member Variable ~unknown ~unresolved");
	
	my $result = 0;
  
	foreach my $attribute (@attributeArray){
		my $attributeClass = $attribute->ent()->ref("Typed", "Class");
		next if (!$attributeClass);		
		next if ($attributeClass->ent()->library() =~ m/Standard/i);
		
		my $attributeClassKey = getClassKey($attributeClass->ent());		
		next if ($attributeClassKey ne getClassKey($sClassD));		
		$result++; 
	}
	  	
	return $result;	
}#END sub getNoOfClassAttributeInteraction


sub getNoOfClassMethodInteraction{
#给定类c和d, 返回从c到d的类-方法交互数目, 也就是类c中以d为参数类型或者返回类型的(新定义的)方法数目
  my $sClassC = shift;
  my $sClassD = shift;	
  
  my $result;
	
	my %addedMethodHash; 
	getAddedMethods($sClassC, \%addedMethodHash);
	
	foreach my $key (keys %addedMethodHash){
		my $func = $addedMethodHash{$key};
		
		my @parameters = $func->ents("Define", "Parameter");
		
		#判断函数的每个参数的类型是不是所指定的类
		foreach my $para (@parameters){			
			my $parameterClass = $para->ref("Typed", "Class");			
			next if (!$parameterClass);
			next if ($parameterClass->ent()->library() =~ m/Standard/i);
			
			my $parameterClassKey = getClassKey($parameterClass->ent());			
			next if ($parameterClassKey ne getClassKey($sClassD));					
			$result++;
		}
		
		#判断函数的返回类型是不是所指定的类
		my $returnClass = $func->ref("Typed", "Class");	
		next if (!$returnClass);
	  next if ($returnClass->ent()->library() =~ m/Standard/i);		
		
		my $returnClassKey = getClassKey($returnClass->ent());
		next if ($returnClassKey ne getClassKey($sClassD));
		$result++;
	}
	
	return $result;	
}#END sub getNoOfClassMethodInteraction


sub getClassnameFromTypename{
#由类型名得到类名, 即去掉*, const, &等符号
  my $sTypename = shift;
  
  
	$sTypename =~ s/\*//g;
	$sTypename =~ s/&//g;
	$sTypename =~ s/const//g;
	$sTypename =~	s/^\s+//;
	$sTypename =~ s/\s+$//;
	
	return $sTypename;	
}#END sub getClassnameFromTypename



sub getNoOfMethodMethodInteraction{
#给定类c和d, 返回从c到d的方法-方法交互数目, 也就是类c中的那些调用了类d中的方法或者以
#类d中方法为参数的方法数目	
  my $sClassC = shift;
  my $sClassD = shift;	

	my @methodArray = $sClassC->refs("define", "function ~unresolved ~unknown, method ~unresolved ~unknown");    
	
	my $result = 0;
  
  #统计以$sClassC中调用类$sClassD中方法的方法数目
  foreach my $method (@methodArray){
  	my @calledFuncSet = $method->ent()->refs("call", "function ~unresolved ~unknown, method ~unresolved ~unknown");
  	foreach my $func (@calledFuncSet){
  		my $calledClass = $func->ent()->ref("Definein", "Class");
  		next if (!$calledClass);  		
  		next if ($calledClass->ent()->library() =~ m/Standard/i);
  		
  		my $calledClassName = getLastName($calledClass->ent()->name());
  		
  		next if ($calledClassName ne getLastName($sClassD->name())); 

  		$result++;
  	}
  }
  
  #统计以$sClassD中方法为参数的(类$sClassC)方法数目
  
  
  return $result;		
}#END sub getNoOfMethodMethodInteraction



sub IMC{
	#计算方法的内部复杂性, 实际上是Halstead的effort公式.  所得结果提供给子程序CBI, 即Degree of coupling of inheritance in a class.
	#Ref: E.M. KIM, S. Kusumoto, T. Kikuno. Heuristics for computing attribute values of C++ program complexity metrics. COMPSAC 1996.
	my $sEnt = shift;   # 方法的实体
	
  
 	my $func = $sEnt;
  
  my ($lexer, $startLine, $endLine) = getLexerStartAndEndLine($func);	  
  return 0 if ($lexer eq "undef");
    
	my ($n1, $n2, $N1, $N2) = scanEntity($lexer,$startLine,$endLine);
	  
  # do the calcs
  my ($n, $N) = ($n1 + $n2, $N1 + $N2);
  
#  print "\t n1 = ", $n1, "\n";
#  print "\t n2 = ", $n2, "\n";
#  print "\t N1 = ", $N1, "\n";
#  print "\t N2 = ", $N2, "\n";
	 	
	return 0 if ($n1 < 1);
	return 0 if ($n2 < 1);
	return 0 if ($N2 < 1); 	
	 	
  my $result = $N * ((log $n)/(log 2)) / ($n1/2 * $n2/$N2);

  return $result;
} # END sub IMC



sub getNoReserveWords{
	#计算方法体中的保留字数目, 提供给子程序MPCnew
	my $sEnt = shift;
	
	my $func = $sEnt;
	
	my %reserveWordsHash = ( if => 1,
	                         else => 1,  
		                       switch => 1,
		                       case => 1,
		                       default => 1,
		                       for => 1,
		                       while => 1,
		                       do => 1,
		                       repeat => 1,
		                       until => 1,
		                       next => 1,
		                       continue => 1,
		                       break => 1,
		                       throw => 1,
		                       try => 1,
		                       catch => 1
		                      );
	
  my ($lexer, $startLine, $endLine) = getLexerStartAndEndLine($func);	  
  return 0 if ($lexer eq "undef");
  
  my $result = 0;
	    
  foreach my $lexeme ($lexer->lexemes($startLine,$endLine)) 
  {
     next if ($lexeme->token() ne "Keyword");  
     next if (!exists $reserveWordsHash{$lexeme->text()});     
     $result++;
  }	
	
	return $result;
}#END sub getNoReserveWords


sub PIM{
	#返回多态调用的方法集
	#目前只能返回静态调用的方法集, 以后扩充成动态调用的方法集  
	my $sEnt = shift;
	my $polyCalledMethodSet = shift; #多态调用的方法集合, 是一个hash表. key是类名+方法基调名, value是(funcEnt, callCount)对
	
#	print "\n\t\t\t computing PIM..." if ($debug);	
	
	my $callingFunc = $sEnt;  
	
	my @calledMethodSet = $callingFunc->refs("Call", "function ~unknown ~unresolved, method ~unknown ~unresolved");
	
	foreach my $calledMethod (@calledMethodSet){
		my $calledFunc = $calledMethod->ent();
		my $calledClass = $calledFunc->ref("Definein", "Class ~unknown ~unresovled");
  	next if (!$calledClass);  		
  	next if ($calledClass->ent()->library() =~ m/Standard/i);  		
  	
  	my $calledFuncSignature = getFuncSignature($calledFunc,1);	
  	
  	my $funcKey = getLastName($calledClass->ent()->name())."::".$calledFuncSignature;
  	
  	if (!exists $polyCalledMethodSet->{$funcKey}){
  		$polyCalledMethodSet->{$funcKey}->{funcEnt} = $calledFunc;
  		$polyCalledMethodSet->{$funcKey}->{callCount} = 1;
  	}
  	else{
  		$polyCalledMethodSet->{$funcKey}->{callCount}++;
  	}
    
    my $callingClass = $callingFunc->ref("Definein", "Class ~unknown ~unresovled");
    my $callingFuncSignature = getFuncSignature($callingFunc,1);	
    my $callingFuncKey = getLastName($callingClass->ent()->name())."::".$callingFuncSignature;
    
#    print "\t\t", $callingFuncKey, "====>", $funcKey, "\n";
##下面的代码返回的集合比真正的动态调用集要大很多, 有待解决  	
##  	print "\t\t called func = ", $calledFunc->name(), "\n"; 
##  	print "\t\t called class = ", $calledClass->ent()->name(), "\n";
#    my %descendentClassHash; 
#    
#    getDescendentClasses($calledClass->ent(), \%descendentClassHash);
#  	
##  	print "NO descendent class ====> ", scalar (keys %descendentClassHash), "\n";
#  	
#  	foreach my $key (keys %descendentClassHash){
#  		my $currentClass = $descendentClassHash{$key};
#  		
# # 		print "\t\t currentClass = ", $currentClass->name(),"\n";
#  		
#  		my $calledFuncEnt; 
#  		my $find;
#  		($find, $calledFuncEnt) = IsImplementedInClass($currentClass, $calledFuncSignature);
#  		next if (!$find);
#  		  		
#  #		print "=========\n";
#
#      my $funcKey = getLastName($currentClass->name())."::".$calledFuncSignature;   		
#      
#  	  if (!exists $polyCalledMethodSet->{$funcKey}){
#  		  $polyCalledMethodSet->{$funcKey}->{funcEnt} = $calledFuncEnt;
#  		  $polyCalledMethodSet->{$funcKey}->{callCount} = 1;
#  	  }
#  	  else{
#  		  $polyCalledMethodSet->{$funcKey}->{callCount}++;
#  	  }      
#  		
##  		print "\t\t class name = ", $currentClass->name(), "\n";
##  		print "\t\t funcEnt = ", $calledFuncEnt->name(), "\n";
#  	}
  }
  
#	print ".....PIM END\n" if ($debug);
	
}#END sub PIM


sub IsImplementedInClass{
	#给定一个类, 以及一个方法的基调, 判断该方法是由该类定义
	my $sClass = shift;
	my $sMethodSignature = shift;
	my $sCalledFuncEnt; #如果存在定义, 则返回该函数实体
	
	my @methodArray = getEntsInClass($sClass, "define", "function ~unknown ~unresolved, method ~unknown ~unresolved");
	
	my $find = 0;
	
	my $i = 0;
	while (!$find && $i < @methodArray){
		my $key = getFuncSignature($methodArray[$i], 1);		
		if ($sMethodSignature eq $key){
			$find = 1;
			$sCalledFuncEnt = $methodArray[$i];
		}
		$i++;
	}
	
	return wantarray?(0, 0):0 if (!$find);	
	
	return wantarray?(1, $sCalledFuncEnt):1;
}#END sub IsImplementedInClass



sub getLexerStartAndEndLine{
	my $sEnt = shift;
	
	my $lexer = $sEnt->ref()->file()->lexer();
		
  my ($startRef) = $sEnt->refs("definein","",1);
  ($startRef) = $sEnt->refs("declarein","",1) unless ($startRef);  
	my ($endRef) = $sEnt->refs("end","",1);
	
	return ("undef", 0, 0) unless ($startRef and $endRef);
		
	my $startLine = $startRef->line();
	my $endLine = $endRef->line();
		
	my $test = $lexer->lexemes($startLine, $endLine);
	while (!$test and $endLine > $startLine){
		$endLine = $endLine - 1;
		$test = $lexer->lexemes($startLine, $endLine);
	}		
	
	return ($lexer, $startLine, $endLine);
}


sub IsMethodInClassHeader{
	my $sClass = shift;
	my $sFunc = shift;
	
	return 1;
	
#	print "sClass->ref()->file()->name() = ", $sClass->ref()->file()->name(), "\n";
#	print "sFunc->ref()->file()->name()) = ", $sFunc->ref()->file()->name(), "\n";

	return 1 if ($sClass->ref()->file()->relname() ne $sFunc->ref()->file()->relname()
	             && $sClass->ref()->file()->name() eq $sFunc->ref()->file()->name());

	return 0 if ($sClass->ref()->file()->name() ne $sFunc->ref()->file()->name());
	
  my ($classStartRef) = $sClass->refs("definein", "", 1);
	my ($classEndRef) = $sClass->refs("end","",1);
#	
#	my @refs = $sClass->refs();
#	print "@refs = ", scalar @refs, "\n";
#	foreach my $sref (@refs){
#		print "ref name = ", $sref->ent()->name(), "\n";
#		print "ref line = ", $sref->line(), "\n";
#		
#	}
		
	my $classStartLine = $classStartRef->line();
	my $classEndLine = $classEndRef->line();    
	
#	print "classStartLine = ", $classStartLine, "\n";
#	print "classEndLine = ", $classEndLine, "\n";

  my ($funcStartRef) = $sFunc->refs("definein", "", 1);
	my ($funcEndRef) = $sFunc->refs("end","",1);
		
	my $funcStartLine = $funcStartRef->line();
	my $funcEndLine = $funcEndRef->line();    
#
#	print "funcStartLine = ", $funcStartLine, "\n";
#	print "funcEndLine = ", $funcEndLine, "\n";

	
	return 1 if ($funcStartLine >= $classStartLine && $funcEndLine <= $classEndLine);
	
	return 0;	
}


sub getTimeInSecond{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	
	my $timePoint = $hour*3600 + $min * 60 + $sec;
	
	return $timePoint;
}

sub reportComputeTime{
	my $startTime = shift; #以秒为单位
	my $subProgramName = shift; #统计该子程序的时间

  my $endTime = getTimeInSecond();
	
	my $timeInComputation = $endTime - $startTime;
	
	print "\t\t\t ", $subProgramName, " takes ", $timeInComputation, " seconds \n"; 
}


sub getEntsInClass{
	#返回类中定义的属性或者方法实体
	#主要处理,一个项目中具有多个版本的类, 当前的understand数据库有问题, 将不同类(具有相同的类名)的属性或者方法
	#合并在一起. 因此, 要正确处理这种情况
	my $sClass = shift;
	my $refKindString = shift;
	my $entKindString = shift;
	
	my @entArray = $sClass->ents($refKindString, $entKindString);
	
	return @entArray;
	
	
#	#类定义所在的文件的相对名
#	my $fileRelNameOfClass = $sClass->ref()->file()->relname();	
#	#类定义所在的文件名
#	my $fileNameOfClass = $sClass->ref()->file()->name();
#	
#	my @result = ();
#	
#	foreach my $ent (@entArray){		
#		#实体定义所在的文件的相对名
#		my $fileRelNameOfEnt = $ent->ref()->file()->relname();
#		#实体定义所在的文件名
#		my $fileNameOfEnt = $ent->ref()->file()->name();
#		
#		#如果相对名不同, 但名相同, 则是相同版本的文件
#		next if ($fileRelNameOfClass ne $fileRelNameOfEnt  
#		         && $fileNameOfClass eq $fileNameOfEnt);
#		
#		push @result, $ent;		
#	}
#	
#	return @result;	
}#END sub getEntsInClass


sub getRefsInClass{
	#返回类中定义的属性或者方法实体
	#主要处理,一个项目中具有多个版本的类, 当前的understand数据库有问题, 将不同类(具有相同的类名)的属性或者方法
	#合并在一起. 因此, 要正确处理这种情况
	my $sClass = shift;
	my $refKindString = shift;
	my $entKindString = shift;
	
	my @entArray = $sClass->refs($refKindString, $entKindString);
	
	return @entArray;
	
#	#类定义所在的文件的相对名
#	my $fileRelNameOfClass = $sClass->ref()->file()->relname();	
#	#类定义所在的文件名
#	my $fileNameOfClass = $sClass->ref()->file()->name();
#	
#	my @result = ();
#	
#	foreach my $aref (@entArray){				
#		my $ent = $aref->ent();
#		#实体定义所在的文件的相对名
#		my $fileRelNameOfEnt = $ent->ref()->file()->relname();
#		#实体定义所在的文件名
#		my $fileNameOfEnt = $ent->ref()->file()->name();
#		
#		#如果相对名不同, 但名相同, 则是相同版本的文件
#		next if ($fileRelNameOfClass ne $fileRelNameOfEnt  
#		         && $fileNameOfClass eq $fileNameOfEnt);
#		
#		push @result, $aref;		
#	}
#	
#	return @result;	
}#END sub getRefsInClass



############################################################################
###自定义SLOC#####注意以下代码changeproness的计算程序中已经有了, 不用再添加#
############################################################################

sub SLOC{
	my $sClass = shift;
	
	my $noOfHeaderStatements = getLinesOfCode($sClass);

  	my $noOfMethodStatements = 0;
 	my @methodArray = getRefsInClass($sClass, "define","function, method ~unknown ~unresolved");
     	
  	foreach my $method (@methodArray){
  		my $func = $method->ent();     		
    
    		#如果方法体的定义包含在类头的定义中,则跳过(很重要, 避免重复计数)
    		next if IsMethodInClassHeader($sClass, $func);     		
    
    		$noOfMethodStatements = $noOfMethodStatements + getLinesOfCode($func);
  	}
	  	
	#自己计算SLOC (Understand的计算方法中除掉了所有的编译指示包含的语句)
	my $result = $noOfHeaderStatements + $noOfMethodStatements;
	
	return $result;  	
}#END sub SLOC


sub getLinesOfCode
{
    my $sEnt = shift;

    my $result;

    # create lexer object
    my ($lexer,$status) = $sEnt->ref()->file()->lexer();
    die "\ncan't open lexer on class, error: $status" if ($status);

    # scan lexemes
    # slurp lines with comments extracted, omit empty lines
    my $text;
    
    my ($lexer, $startLine, $endLine) = getLexerStartAndEndLine($sEnt); 
		return 0 if ($lexer eq "undef");
		
#		print "name = ", $sEnt->longname(), "\n";
#		print "startLine = ", $startLine, "\n";
#		print "endLine = ", $endLine, "\n";
    
    
    foreach my $lexeme ($lexer->lexemes($startLine, $endLine)){
     	# save non-blank strings when newline is encountered
	    if ( $lexeme->token() eq "Newline" ) {
	      if ( $text =~ /[0-9a-zA-Z_{}]/ ){	      	
		       $result++;
	      }

	      # clear text
	      $text = "";
	      next;
	    }

	    # append to text if code, skipping all comments
	    if ( $lexeme->token() !~ /Comment/g ) {
	       $text .= $lexeme->text();	    
	    } 

    } #End for

    return $result;
}#END sub getLinesOfCode













#NOP:   CountClassBase
#CBO:   CountClassCoupled
#NOC:   CountClassDerived
#NIM:   CountDeclInstanceMethod
#NIV:   CountDeclInstanceVariable
#WMC:   CountDeclMethod
#RFC:   CountDeclMethodAll
#DIT:   MaxInheritanceTree
#LCOM:  PercentLackOfCohesion

#
#
#
#=====================数据集中面向对象度量的说明===================================
#(修订日期:2008年7月23日)
#
#1.复杂性度量
#  (1)CDE 
#     a. 全称: Class Definition Entropy
#     b. 出处: J. Bansiya, C. Davis, L. Etzkorn. An entropy-based complexity measure for object-oriented designs. Theory 
#              and Practice of Object Systems, 5(2), 1999: 111-118.
#     c. 性质: 
#     
#  (2)CIE    
#     a. 全称: Class Implementation Entropy
#     b. 出处: 同CIE
#     c. 性质:    
#
#  (3)WMC    
#     a. 全称: Weighted Method Per Class 
#     b. 出处: S.R. Chidamber, C.F. Kemerer.A metrics suite for object-oriented design. IEEE TSE, 20(6), 1994: 476-493.
#     c. 性质: 
#     
#  (4)SDMC    
#     a. 全称: Standard Deviation Method Complexity 
#     b. 出处: Michura J, Capretz MAM. Metrics suite for class complexity. International Conference on Information Technology: 
#              Coding and Computing, 2005; 404–409.
#     c. 性质: 
#
#  (5)AWMC    
#     a. 全称: Average Method Complexity (the average of cyclomatic complexity of all methods in a class, i.e. CCAvg)
#     b. 出处: Etzkorn LH, Bansiya J, Davis C. Design and code complexity metrics for OO classes. Journal of Object-oriented
#              Programming 1999; 12(1):35–40.
#     c. 性质: 
#
#  (6)CCMax    
#     a. 全称: Maximum cyclomatic complexity of a single method of a class 
#     b. 出处: H.M. Olague, L.H. Etzkorn, S.L. Messimer, H.S. Delugach. An empirical validation of object-oriented class
#              complexity metrics and their ability to predict error-prone classes in highly iterative, or agile, software:
#              a case study. Journal of Software Maintenance and Evolution: Research and Practice, 2008, 3.
#     c. 性质: 
#
#  (7)NTM    
#     a. 全称: Number of Trival Methods (the number of local methods in the class whose McCabe complexity value is 
#              equal to one.
#     b. 出处: McCabe TJ. A complexity measure. IEEE Transactions on Software Engineering 1976; 2(4):308–320.
#     c. 性质: 
#
#  (8)CC1    
#     a. 全称: Class Complexity One 
#     b. 出处: Y.S. Lee, B.S. Liang, F.J. Wang. Some complexity metrics for OO programs based on information flow. IEEE 
#              COMPEURO 1993: 302-310.
#     c. 性质: 
#     
#  (9)CC2    
#     a. 全称: Class Complexity Two 
#     b. 出处: 同CC1
#     c. 性质: 
#     
#  (10)CC3    
#     a. 全称: Class Complexity Three 
#     b. 出处: K. Kim, Y. Shin, C. Wu. Complexity measures for OO program based on the entropy. APSEC 1995: 127-136.
#     c. 性质: 
#
#
#2.耦合性度量
#  (1)CBO    
#     a. 全称: Coupling Between Object 
#     b. 出处: 同WMC
#     c. 性质: 
#
#  (2)RFC    
#     a. 全称: Response For a Class, 包括自身顶的方法和所有直接或者间接调用的方法 
#     b. 出处: 
#     c. 性质:      
#
#  (3)RFC1    
#     a. 全称: Response For a Class, 只包括自身定义的方法和直接调用的方法 
#     b. 出处: S.R. Chidamber, C.F. Kemerer. Towards a metrics suite for object-oriented design. OOPSLA 1991: 197-211.
#     c. 性质:      
#
#  (3)MPC
#     a. 全称: Message Passing Coupling
#     b. 出处: W. Li, S. Henry. Object-oriented metrics that predict maintainability, JSS, 23(2), 1993: 11-122
#     c. 性质:   
#
#  (4)MPCNew
#     a. 全称: Message Passing Coupling (Number of send statements in a class)
#     b. 出处: E.M. Kim, S. Kusumoto, T. Kikuno. Heuristics for computing attribute values of C++ program complexity 
#              metrics. COMPSAC 1996: 104-109.  
#     c. 性质:   
#
#  (5)DAC
#     a. 全称: Data Abstraction Coupling: 类型是其他类的属性数目
#     b. 出处: 同MPC
#     c. 性质:   
#
#  (6)DACquote
#     a. 全称: Data Abstraction Coupling: 类型是其他类的类的数目
#     b. 出处: 同MPC
#     c. 性质:   
#
#  (7)ICP
#     a. 全称: Information-flow-based Coupling
#     b. 出处: Y.S. Lee, B.S. Liang, S.F. Wu, F.J. Wang. Measuring the coupling and cohesion of an object-oriented 
#              program based on information flow. ICSQ 1995.
#     c. 性质:   
#
#  (8)IHICP
#     a. 全称: Information-flow-based inheritance Coupling
#     b. 出处: 同ICP
#     c. 性质: 
#
#  (9)NIHICP
#     a. 全称: Information-flow-based non-inheritance Coupling
#     b. 出处: 同ICP
#     c. 性质: 
#     
#  (10)IFCAIC
#     a. 全称: Inverse friends class-attribute interaction import coupling
#     b. 出处: L.C. Briand, P. Devanbu, W. Melo. An investigation into coupling metrics for C++. ICSE 1997: 412-421.
#     c. 性质: 
#     
#  (11)ACAIC
#     a. 全称: Ancestor classes class-attribute interaction import coupling
#     b. 出处: 同IFCAIC
#     c. 性质: 
#
#  (12)OCAIC
#     a. 全称: Others class-attribute interaction import coupling
#     b. 出处: 同IFCAIC
#     c. 性质: 
#     
#  (13)FCAEC
#     a. 全称: Friends class-attribute interaction export coupling
#     b. 出处: 同IFCAIC
#     c. 性质:     
#
#  (14)DCAEC
#     a. 全称: Descendents class class-attribute interaction export coupling
#     b. 出处: 同IFCAIC
#     c. 性质:   
#
#  (15)OCAEC
#     a. 全称: Others class-attribute interaction export coupling
#     b. 出处: 同IFCAIC
#     c. 性质:   
#
#  (16)IFCMIC
#     a. 全称: Inverse friends class-method interaction import coupling
#     b. 出处: 同IFCAIC
#     c. 性质: 
#
#  (17)ACMIC
#     a. 全称: Ancestor class class-method interaction import coupling
#     b. 出处: 同IFCAIC
#     c. 性质: 
#     
#  (18)OCMIC
#     a. 全称: Others class-method interaction import coupling
#     b. 出处: 同IFCAIC
#     c. 性质:      
#     
#  (19)FCMEC
#     a. 全称: Friends class-method interaction export coupling
#     b. 出处: 同IFCAIC
#     c. 性质: 
#
#  (20)DCMEC
#     a. 全称: Descendents class-method interaction export coupling
#     b. 出处: 同IFCAIC
#     c. 性质: 
#
#  (21)OCMEC
#     a. 全称: Others class-method interaction export coupling
#     b. 出处: 同IFCAIC
#     c. 性质: 
#
#  (22)OMMIC
#     a. 全称: Others method-method interaction import coupling
#     b. 出处: 同IFCAIC
#     c. 性质: 
#
#  (23)IFMMIC
#     a. 全称: Inverse friends method-method interaction import coupling
#     b. 出处: 同IFCAIC
#     c. 性质:
#
#  (24)AMMIC
#     a. 全称: Ancestor class method-method interaction import coupling
#     b. 出处: 同IFCAIC
#     c. 性质:
#
#  (25)OMMEC
#     a. 全称: Others method-method interaction export coupling
#     b. 出处: 同IFCAIC
#     c. 性质:
#
#  (26)FMMEC
#     a. 全称: Friends method-method interaction export coupling
#     b. 出处: 同IFCAIC
#     c. 性质:
#     
#  (27)DMMEC
#     a. 全称: Descendents method-method interaction export coupling
#     b. 出处: 同IFCAIC
#     c. 性质:    
#
#  (28)CBI
#     a. 全称: Degree of coupling of inheritance
#     b. 出处: E.M. Kim, S. Kusumoto, T. Kikuno. Heuristics for computing attribute values of C++ program complexity 
#              metrics. COMPSAC 1996: 104-109.  
#     c. 性质: 
#
#  (29)UCL
#     a. 全称: Number of classes used in a class except for ancestors and children
#     b. 出处: 同CBI  
#     c. 性质:  
#
#  (30)CC
#     a. 全称: Class Coupling
#     b. 出处: C. Rajaraman, M.R. Lyu. Reliability and maintainability related software coupling metrics in C++ programs.
#     c. 性质:  
# 
#  (31)AMC
#     a. 全称: Average Method Coupling
#     b. 出处: 同CC
#     c. 性质:  
#  
#
#3.继承性相关度量
#  (1)NOC
#     a. 全称: Number Of Child Classes
#     b. 出处: 同WMC
#     c. 性质:  
#
#  (2)NOP
#     a. 全称: Number Of Parent Classes
#     b. 出处: M. Lorenz, J. Kidd. Object-oriented software metrics: a practical guide. Prentice-Hall, 1994
#     c. 性质:  
#
#  (3)DIT
#     a. 全称: Depth of Inheritance Tree
#     b. 出处: 同WMC
#     c. 性质: 
#     
#  (4)AID
#     a. 全称: Average Inheritance Depth of a class
#     b. 出处: B.Henderson-sellers. Object-oriented metrics: measures of complexity, Prentice Hall, 1996
#     c. 性质:      
#
#  (5)CLD
#     a. 全称: Class-to-Leaf Depth
#     b. 出处: D.P. Tegarden, S.D. Sheetz, D.E. Monarchi. A software complexity model of object-oriented systems. 
#              Decision SupportSystems, 13(3–4), 1995: 241–262.
#     c. 性质:      
#
#  (6)NOD
#     a. 全称: Number Of Descendents
#     b. 出处: 同CLD
#     c. 性质: 
#
#  (7)NOA
#     a. 全称: Number Of Ancestors
#     b. 出处: 同CLD
#     c. 性质: 
#
#  (8)NMO
#     a. 全称: Number of Methods Overridden
#     b. 出处: 同NOP
#     c. 性质: 
#
#  (9)NMI
#     a. 全称: Number of Methods Inherited
#     b. 出处: 同NOP
#     c. 性质: 
#
#  (10)NMA
#     a. 全称: Number Of Methods Added
#     b. 出处: 同NOP
#     c. 性质: 
#
#  (11)SIX
#     a. 全称: Specialization IndeX   =  NMO * DIT / (NMO + NMA + NMI)
#     b. 出处: 同NOP
#     c. 性质: 
#     
#  (12)PII
#     a. 全称: Pure Inheritance Index
#     b. 出处: B.K. Miller, P. Hsia, C. Kung. Object-oriented architecture measures. 32rd Hawaii International Conference 
#              on System Sciences 1999 
#     c. 性质: 
#     
#  (13)SPA
#     a. 全称: static polymorphism in ancestors
#     b. 出处: S. Benlarbi, W.L. Melo. Polymorphism measures for early risk prediction. 
#              ICSE 1999: 334-344.
#     c. 性质:
#
#  (14)SPD
#     a. 全称: static polymorphism in decendants
#     b. 出处: 同SPA
#     c. 性质:
#     
#  (15)DPA
#     a. 全称: dynamic polymorphism in ancestors
#     b. 出处: 同SPA
#     c. 性质:     
#
#  (16)DPD
#     a. 全称: dynamic polymorphism in decendants
#     b. 出处: 同SPA
#     c. 性质: 
#     
#  (17)SP
#     a. 全称: static polymorphism in inheritance relations
#     b. 出处: 同SPA
#     c. 性质: 
#     
#  (18)DP
#     a. 全称: dynamic polymorphism in inheritance relations
#     b. 出处: 同SPA
#     c. 性质:    
#     
#  (19)CHM
#     a. 全称: Class hierarchy metric
#     b. 出处: J.Y. Chen, J.F. Lu. A new metric for OO design. IST, 35(4): 1993.
#     c. 性质:  
#     
#  (20)DOR
#     a. 全称: Degree of reuse by inheritance
#     b. 出处: E.M. Kim, S. Kusumoto, T. Kikuno. Heuristics for computing attribute values of C++ program complexity 
#              metrics. COMPSAC 1996: 104-109.
#     c. 性质:             
#     
#
#4.规模度量
#  (1)NMIMP
#     a. 全称: Number Of Methods Implemented in a class
#     b. 出处: 
#     c. 性质:    
#
#  (2)NAIMP
#     a. 全称: Number Of Attributes Implemented in a class
#     b. 出处: 
#     c. 性质: 
#  
#  (3)SLOC
#     a. 全称: source lines of code
#     b. 出处: 
#     c. 性质:
#  
#  (4)SLOCExe
#     a. 全称: source lines of executable code
#     b. 出处: 
#     c. 性质:
#
#  (5)stms
#     a. 全称: number of statements
#     b. 出处: 同NM
#     c. 性质:
#
#  (6)stmsExe
#     a. 全称: number of executable statements
#     b. 出处: 
#     c. 性质:
#     
#  (7)NM
#     a. 全称: number of all methods (inherited, overriding, and non-inherited) methods of a class
#     b. 出处: L.C. Briand, J. Wust, J.W. Daly, D.V. Porter. Exploring the relationships between design measures and
#              software quality in object-oriented systems. JSS, 51(3), 2000: 245-273.
#     c. 性质:     
#     
#  (8)Nmpub
#     a. 全称: number of public methods implemented in a class
#     b. 出处: 同NM
#     c. 性质:     
#     
#  (9)NMNpub
#     a. 全称: number of non-public methods implemented in a class
#     b. 出处: 同NM
#     c. 性质:     
#
#  (10)NumPara
#     a. 全称: sum of the number of parameters of the methods implemented in a class
#     b. 出处: 同NM
#     c. 性质:     
#
#  (11)NIM    
#     a. 全称: Number of Instance Methods (the number in an instance object of a class. This is different from a class
#              method, which refers to a method which only operates on data belonging to the class itself, not on data 
#              that belong to individual objects. 
#     b. 出处: Lorenz M, Kidd J. Object-oriented Software Metrics, 1994; 146.
#     c. 性质: 
#     
#  (12)NCM    
#     a. 全称: Number of Class Methods
#     b. 出处: Lorenz M, Kidd J. Object-oriented Software Metrics, 1994; 146.
#     c. 性质: 
#     
#  (13)NLM    
#     a. 全称: Number of Local Methods (NLM = NIM + NCM = NMIMP) 
#     b. 出处: 
#     c. 性质: 
#     
#  (14)AvgSLOC    
#     a. 全称: Average Source Lines of Code (Average of the lines of code of a class) 
#     b. 出处: H.M. Olague, L.H. Etzkorn, S.L. Messimer, H.S. Delugach. An empirical validation of object-oriented class
#              complexity metrics and their ability to predict error-prone classes in highly iterative, or agile, software:
#              a case study. Journal of Software Maintenance and Evolution: Research and Practice, 2008, 3.
#     c. 性质: 
#
#  (15)AvgSLOCExe    
#     a. 全称: Average Source Lines of Executable Code (Average of teh executable lines of code of a class) 
#     b. 出处: H.M. Olague, L.H. Etzkorn, S.L. Messimer, H.S. Delugach. An empirical validation of object-oriented class
#              complexity metrics and their ability to predict error-prone classes in highly iterative, or agile, software:
#              a case study. Journal of Software Maintenance and Evolution: Research and Practice, 2008, 3.
#     c. 性质: 
#
#
#5.内聚性度量
#  (1)LCOM1
#     a. 全称: 
#     b. 出处: 同RFC1
#     c. 性质:
#
#  (2)LCOM2
#     a. 全称: 
#     b. 出处: 同WMC
#     c. 性质:
#
#  (3)LCOM3
#     a. 全称: 
#     b. 出处: 同Co
#     c. 性质:
#
#  (4)LCOM4
#     a. 全称: 
#     b. 出处: 同Co
#     c. 性质:
#
#  (5)Co
#     a. 全称: 
#     b. 出处: M. Hitz, B. Montazeri. Measuring coupling and cohesion in object-oriented systems. SAC 1995: 25-27
#     c. 性质:
#
#  (6)NewCo
#     a. 全称: 
#     b. 出处: 同NewLCOM5
#     c. 性质:
#
#  (7)LCOM5
#     a. 全称: 
#     b. 出处: 同AID
#     c. 性质:
#
#  (8)NewLCOM5 
#     a. 全称: also called NewCoh/Coh
#     b. 出处: L.C. Briand, J.W. Daly, J. Wust. A unified framework for cohesion measurement in object oriented systems.
#              Empirical Software Engineering, 3(1), 1998: 65-117.
#     c. 性质:
#
#  (9)LCOM6
#     a. 全称: based on parameter names.
#     b. 出处: J.Y. Chen, J.F. Lu. A new metric for OO design. IST, 35(4): 1993.
#     c. 性质:     
#     
#  (10)LCC 
#     a. 全称: Loose Class Cohesion
#     b. 出处: J.M. Bieman, B.K. Kang. Cohesion and reuse in an object-oriented system. Proceedings of ACM Symposium on 
#              Software Reusability, 1995: 259-262.
#     c. 性质:
#     
#  (11)TCC 
#     a. 全称: Tight Class Cohesion
#     b. 出处: 同LCC
#     c. 性质:     
#
#  (12)ICH 
#     a. 全称: Information-flow-based Cohesion
#     b. 出处: 同ICP
#     c. 性质:
# 
#  (13)DCd 
#     a. 全称: Degree of Cohesion based Direct relations between the public methods
#     b. 出处: Linda Badri and Mourad Badri. A Proposal of a New Class Cohesion Criterion: An Empirical Study.
#              Journal of Object Technology, 3(4), 2004: 145-159.
#     c. 性质:
#
#  (14)DCi 
#     a. 全称: Degree of Cohesion based Indirect relations between the public methods
#     b. 出处: 同DCd
#     c. 性质:
# 
#  (15)CBMC 
#     a. 全称: 
#     b. 出处: 
#     c. 性质:
#
#  (16)ICBMC 
#     a. 全称: 
#     b. 出处: 
#     c. 性质:
#
#  (17)ACBMC 
#     a. 全称: 
#     b. 出处: 
#     c. 性质:
#  
#  (18)C3 
#     a. 全称: conceptual cohesion of classes
#     b. 出处: A. Marcus, D. Poshyvanyk. The conceptual cohesion of classes. ICSM 2005.
#     c. 性质:
#  
#  (19)LCSM 
#     a. 全称: Lack of Conceptual similarity between Methods
#     b. 出处: 同C3
#     c. 性质:
#
#  (20)OCC 
#     a. 全称: Opitimistic Class Cohesion
#     b. 出处: Aman H., Yamasaki K., Yamada H. Noda M., “A Proposal of Class Cohesion Metrics Using Sizes of Cohesive 
#              Parts”, Knowledge-based Software Engineering, T. welzer et al.(Eds.), pp102-107, IOS Press, Sept. 2002.
#     c. 性质:
#
#  (21)PCC 
#     a. 全称: Pessimistic Class Cohesion
#     b. 出处: 同OCC
#     c. 性质:
#
#  (22)CAMC 
#     a. 全称: Cohesion Among Methods in a Class
#     b. 出处: J. Bansiya, L. Etzkorn, C. Davis, W. Li. A class cohesion metric for object-oriented designs. 
#              JOOP, 11(8), 1999: 47-52.
#     c. 性质:
#
#  (23)iCAMC 
#     a. 全称: 包含方法返回值类型的CAMC
#     b. 出处: 
#     c. 性质:
#
#  (24)CAMCs 
#     a. 全称: 包含self类型的CAMC
#     b. 出处: 同CAMC
#     c. 性质:     
#     
#  (25)iCAMCs 
#     a. 全称: 包含方法返回值类型和self类型的CAMC
#     b. 出处: 
#     c. 性质:     
#
#  (26)NHD 
#     a. 全称: Normalized Hamming Distance metric
#     b. 出处: S. Counsell, E. Mendes, S. Swift, A. Tucker. Evaluation of an object-oriented cohesion
#             metric through Hamming distances. Tech. Rep. BBKCS-02-10, Birkbeck College, University of London, UK, 2002.
#     c. 性质: 
#
#  (27)iNHD 
#     a. 全称: 
#     b. 出处: 
#     c. 性质: 
#     
#  (28)NHDs 
#     a. 全称: 
#     b. 出处: 
#     c. 性质: 
#     
#  (29)iNHDs 
#     a. 全称: 
#     b. 出处: 
#     c. 性质: 
#
#  (30)SNHD 
#     a. 全称: Scaled NHD metric 
#     b. 出处: S. Counsell, S. Swift, J. Crampton. The interpretation and utility 
#              of three cohesion metrics for object-oriented design. 
#              ACM Transactions on Software Engineering and Methodology, 15(2), 2006: 123-149.
#     c. 性质:     
#     
#  (31)iSNHD 
#     a. 全称:  
#     b. 出处: 
#     c. 性质:     
#     
#  (32)SCOM 
#     a. 全称: Sensitive Class Cohesion Metric 
#     b. 出处: L. Fernandez, R. Pena. A sensitive metric of class cohesion. International Journal of 
#              Information Theories & Applications, 13(1), 2006: 82-91.
#     c. 性质:     
#     
#  (33)CAC 
#     a. 全称: Class Abstraction Cohesion 
#     b. 出处: B.K. Miller, P. Hsia, C. Kung. Object-oriented architecture measures. 
#              32rd Hawaii International Conference on System Sciences 1999
#     c. 性质:     
#     
#     
#6.其他度量
#  (1)OVO 
#     a. 全称: parametric overloading metric
#     b. 出处: 同SPA
#     c. 性质:   
#     
#  (2)MI 
#     a. 全称:  Maintainability Index
#     b. 出处: 
#     c. 性质:   
#     
#     
#7. 易测性度量
#   (1) testingCSLOC
#     a. 全称: 测试类的SLOC
#     b. 出处: M. Bruntink, A. van Deursen. An empirical study into class testability. JSS, 79(9), 2006: 1219-1232.
#   
#   (2) countOfAssertFunction
#     a. 全称: 测试类中Assert语句的数目
#     b. 出处: 同testingCSLOC
#
#8. Change-proneness度量
#   (1) totalChangedsloc
#     a. 全称: 类中增加与删除的SLOC之和(一个changed的语句看做一次删除和一次增加, 因此计2)
#     b. 出处: (I)E. Arisholm, L.C. Briand, A. Foyen. Dynamic coupling measurement for object-oriented software. 
#                 IEEE TSE, 30(8), 2004: 491-506.
#              (II) W. Li, S.M. Henry. Object-oriented metrics that predict maintainability. JSS, 23(2), 1993: 111-122.