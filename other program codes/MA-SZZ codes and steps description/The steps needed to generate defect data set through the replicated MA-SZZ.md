This document is to be maintained and is currently only available in Chinese.  
通过复现的MA-SZZ生成缺陷数据集所需步骤：  
0.选取5个通过github和jira管理的项目，按高星排序，且这些项目在GitHub不存在版本的发布日期相同或乱序的情况（如高版本的发布日期反而早于低版本），并且版本数量要大于等于10。  
   ("zeppelin","shiro","maven","flume","mahout")  
1.SZZApplication_v1.java从JIRA获取问题报告projectName.csv  
   java爬虫，JQL查询语言  
   java文件：SZZApplication_v1.java，JiraRetriever.java  
   保存路径：mySZZ\issue_reports_from_JIRA\issue_reports\projectName\projectName.csv  
2.get_git_log_from_github_project_local.ps1从github上clone的本地仓库获取git_log.csv  
   powershell脚本, git log命令:git log --date=iso --name-only --since='2003-1-1' --pretty=format:'%H#SEP#%ad#SEP#%cd#SEP#%s'  
   保存路径：mySZZ\git_log_from_GitRepository\projectName\git_log.csv  
3.main_maching_bugFixingCommits_sha.py根据projectName.csv和git_log.csv匹配bug-fixing的commitsha。projectName_bug_commit_all.txt  
   python脚本，正则匹配  
   保存路径：mySZZ\matching_bugid_fixingsha\projectName_bug_commit_all.txt  
   结果示例：FLUME-3328 6f33de9bfca7f6d4a30043c0387f2c534dac7440 2019-04-04 15:35:00 2019-05-03 11:49:04（问题报告创建时间与修复时间）  
4.git_show.ps1获得bug-fixing的commitsha所对应的修改信息projectName_commitsha.txt  
   powershell脚本, git show命令:git show  
   保存路径：mySZZ\git_show_bugFixingCommitsID\projectName\projectName_commitsha.txt  
5.main_getBuggyLineNum_from_git_show_txt.py获得bug-fixing的commitsha中有效的被修复的java文件名，有效的被修改的行的行号。过滤分支合并、非可编译的代码和格式更改。buggyFileAndLineNum_projectName_commitsha.txt  
   python脚本，正则过滤  
   保存路径：mySZZ\buggyFileAndLineNum_from_git_show\projectName\buggyFileAndLineNum_projectName_commitsha.txt  
   结果示例：56,56 0ab026e07b7c852454dd2b9a281f81249cf3d52f^ zeppelin-interpreter/src/main/java/org/apache/zeppelin/interpreter/util/InterpreterOutputStream.java  
6.git_blame_l.ps1由bug-fixing的commitsha的前一次提交(^)，获得bug-introducing的commitsha，文件名，作者，引入时间，引入bug的代码行。projectName_commitsha_pre.txt  
   powershell脚本, git blame命令:git blame -l -f -L $blameline $commitsha_pre $filedir  
   保存路径：mySZZ\git_blame_l_from_buggyFileAndLineNum\projectName\projectName_commitsha_pre.txt  
   结果示例：31ecbbf79f6b9f2483a48bcdd6e81d0ff7ae594c src/java/com/cloudera/flume/master/FlumeMaster.java (Andrew Bayer 2011-08-02 16:03:58 +0000 152)     ConfigurationManager base = new ConfigManager(cfgStore);
7.main_find_bugIntroducingTime.py获得每个引入buggy line的提交号和引入时间，修复提交号和修复时间，问题报告的创建时间。并过滤引入时间大于创建时间的引入提交。buggyLinesIntervals.csv  
   python脚本，正则匹配  
   保存路径：mySZZ\bugIntroducingTime_and_bugFixingtime\projectName\buggyLinesIntervals.csv  
8.main_generateUdb.py调用understand工具从源代码生成每个版本的udb文件  
   python脚本，understand命令，括号中的是需要替换的: und create -db (udbPath_saved) -languages java add (sourceCodePath) analyze -all  
   保存路径：mySZZ\GetMetrics\udb\projectName\projectName-version.udb  
9.main_getMetrics_from_udb.py为每个udb文件通过python调用perl脚本自动抽取度量  
   python脚本main_getMetrics_from_udb.py，pythonCallperl.py，perl脚本qm_java.pl  
   保存路径：mySZZ\GetMetrics\metrics\projectName\projectName-version.csv  
10.main_merge.py对生成的度量文件合并内部类。因为取度量的时候会受内部类的影响，会生成多个相同文件名的情况，所以需要过滤。  
   python脚本  
   保存路径：mySZZ\GetMetrics\metrics_mergeInnerClass\projectName\projectName-version.csv  
11.从github或本地git仓库获取所需版本的发布日期releaseDate.txt  
   保存路径：mySZZ\MappingBugsToVersions\releaseDate\projectName\releaseDate.txt  
   结果示例：0.5.0,2015-07-11  
12.labeling_v2.R根据版本的发布日期releaseDate.txt、bug的引入时间和修复时间buggyLinesIntervals.csv，为每个版本的度量文件projectName-version.csv生成bug标签。projectName-version.csv  
   R脚本  
   保存路径：mySZZ\MappingBugsToVersions\bugDataSet\projectName\projectName-version.csv  