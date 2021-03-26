#repos is stored in T:
#$datasets = @("rhc","sling","DSpace","fenixedu-academic","jackrabbit-oak","open-build-service","origin","sonarqube")
#$datasets = @("hbase","hadoop-common","derby","mahout","openjpa","geronimo","camel","activemq","pig")
#$datasets = @("tuscany-sca-2.x")
#$datasets = @("avro","cxf","drill","hive","jmeter","log4j","poi","wicket","xerces-c","groovy","pdfbox","bigtop","uima-uimaj",
#","openmeetings","nifi","flink","flume","sqoop")
#$datasets = @("kafka","flink","rocketmq","zookeeper","zeppelin","beam","ignite", "shiro", "maven", "flume")
#$datasets = @("ignite", "shiro", "maven", "flume")
$datasets = @("mahout")

cd D:\workspace\mixed-workspace\mySZZ\GitRepository

#git config merge.renameLimit 999999
git config --global merge.renameLimit 999999

foreach($project in $datasets)
{
	write-host "now doing $($project)"
    #get git log
    $logPath = "D:\workspace\mixed-workspace\mySZZ\git_log_from_GitRepository\$($project)\git_log.csv"
	if( !(Test-Path $logPath) )
	{
		write-host "write $($project) git_log.csv"
		cd .\$project
	    git log --date=iso --name-only --since='2003-1-1' --pretty=format:'%H#SEP#%ad#SEP#%cd#SEP#%s' > $($logPath)
        cd ..
	}
}
    
write-host "End..."