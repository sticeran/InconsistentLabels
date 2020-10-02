# library(gsubfn)

#把工作路径设置到path
path = "D:\\workspace\\mixed-workspace\\mySZZ\\issue_reports_from_JIRA\\getBugID_from_issue_reports"
setwd(path)

# projectName_list = c("kafka","flink","rocketmq","zookeeper","zeppelin","beam","ignite","shiro","maven","flume")
projectName_list = c("zeppelin","shiro","maven","flume","mahout","geode")
# 要读取的数据集文件的公共路径
path_common = "D:/workspace/mixed-workspace/mySZZ/issue_reports_from_JIRA/issue_reports"
#存储路径的公共路径
saved_common = "D:/workspace/mixed-workspace/mySZZ/issue_reports_from_JIRA/getBugID_from_issue_reports"



#===主函数体===#
for (i_projectName in projectName_list)
{
  # 一个项目的问题报告路径
  folderName_project = paste(path_common,i_projectName, sep = "/")
  # 得到该路径下所有文件
  fileList = list.files(folderName_project)#list.files命令得到"folderName_project"文件夹下所有文件夹的名称
  
  bugID = c()
  temp_bugID = c()
  for (i_file in fileList)
  {
    # 打印当前文件名
    print(i_file)
    
    # 获取文件路径名
    file = paste(folderName_project,i_file, sep = "/")#问题报告文件路径
    # 问题报告
    df_file = read.table(file=file, header=TRUE, sep=",")
    temp_df_file = subset(df_file,type=="Bug" & resolution=="Fixed")
    temp_df_file2 = subset(temp_df_file,status=="Closed" | status=="Resolved" )
    temp_bugID = temp_df_file2$issueKey
    # temp_bugID = df_file$issueKey[df_file$type=="Bug" & df_file$resolution=="Fixed"]
    # temp_bugID = df_file$issueKey
    bugID = c(bugID,as.vector(temp_bugID))
  }
  # prefix_bugID = paste(toupper(i_projectName),'-',sep="")#问题报告ID前的项目名
  # bugID = gsub(prefix_bugID, "", bugID)#去掉前缀，只保留bugID
  # bugID = as.numeric(bugID)
  
  saved_dir = paste(saved_common,i_projectName,sep = "/")#得到保存预测结果的文件目录
  if (!dir.exists(saved_dir)){
    dir.create(saved_dir)
  }
  saved_path = paste(saved_dir,"bugID.txt",sep = "/")#得到保存预测结果的文件路径
  write.table(bugID, saved_path, sep = "", row.names = FALSE,col.names=F,quote=F)#字符串存入文件时不要引号
}
#===end===#



