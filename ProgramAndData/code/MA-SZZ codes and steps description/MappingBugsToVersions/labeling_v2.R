
# "./"引用当前目录，
# "../"引用上一级目录

library ("hash")

setwd("D:/workspace/mixed-workspace/mySZZ")

# projectName_list = c("kafka","flink","rocketmq","zookeeper","zeppelin","beam","shiro","maven","flume")#"ignite"不能要了，太大了
# projectName_list = c("zeppelin","shiro","maven","flume","mahout")
projectName_list = c("zeppelin")
#存储路径的公共路径
savedPath_common = "./MappingBugsToVersions/bugDataSet"

# x <- c(0,1,1,0,1)
# y <- c(1,0,1,0,1)
# x <- c(1,0,1,0,1)
# y <- c(1,0,1,0,1)
# # aaa = identical(x,y)
# list_x  <- list(c(3,4),c(6,7))
# x  = c(3,4)
# aaa = all(x %in% list_x)

#===主函数体===#
for (i_projectName in projectName_list)
{
  # 一个项目的releaseDate路径
  folderName_releaseDate <- paste("./MappingBugsToVersions/releaseDate",i_projectName, "releaseDate.txt", sep = "/")
  folderName_BuggyIntervals <- paste("./bugIntroducingTime_and_bugFixingtime",i_projectName, "buggyLinesIntervals.csv", sep = "/")
  releaseDate <- read.csv(folderName_releaseDate, header = FALSE, stringsAsFactors = FALSE)
  intervals <- read.csv(folderName_BuggyIntervals, header = TRUE, stringsAsFactors = FALSE)
  # 存储公共路径
  saved_common = paste(savedPath_common,i_projectName,sep = "/")
  
  # process interval data
  itvh <- hash()
  for(bid in 1:nrow(intervals)){
    filename <- intervals$bugFilename[bid]
    # if(filename == "postgresql/src/test/java/org/apache/zeppelin/postgresql/PostgreSqlInterpreterTest.java"){
    #   temp = paste(filename, "buggy file", sep = " ")
    #   print(temp)
    # }
    temp_v2 <- as.Date(intervals$bugIntroducingTime[bid])#将“2011/8/2”转化为2011-08-02
    temp_v2 <- as.numeric(gsub("-","",temp_v2))#将2011-08-02转化为20110802
    temp_v3 <- as.Date(intervals$bugFixingTime[bid])
    temp_v3 <- as.numeric(gsub("-","",temp_v3))
    itv <- c(temp_v2, temp_v3)
    if(has.key(filename, itvh)){
      .set(itvh, keys = filename, values = c(values(itvh, keys = filename), itv))
    }
    else
      .set(itvh, keys = filename, values = c(itv))
  }
  
  # 为每个版本的数据生成bug标签
  len_releaseDate <- nrow(releaseDate)
  for(tid in 1:len_releaseDate)#从第1个到最后一个
  {
    target <- unlist(releaseDate[tid,])#从带列名的一行转为字符串数组
    fileName_metrics <- paste(i_projectName,"-",target[1],".csv",sep = "")#生成文件名
    cat(fileName_metrics, "\n")#打印当前文件名
    
    # 读当前版本的度量文件（不含bug标签）
    folderName_metrics <- paste("./GetMetrics/metrics_mergeInnerClass",i_projectName, fileName_metrics, sep = "/")
    df_file = read.table(file=folderName_metrics, header=TRUE, sep="," ,stringsAsFactors = FALSE)
    
    # 三个日期：前一个版本，当前版本，后一个版本。只需要当前版本就够了
    # rd1 <- releaseDate[(tid-1), 2]
    rd2 <- releaseDate[tid, 2]
    # rd3 <- releaseDate[(tid+1), 2]
    rd2 <- as.numeric(gsub("-","",rd2))#将2011-08-02转化为20110802，不加这句话会发生严重的错误，这是通过回溯不一致标签发现的。
    
    # 判断bug标签
    bug_label <- rep(0, times = nrow(df_file))
    for(i in 1:nrow(df_file)){
      filename <- gsub("\\\\","/", df_file$name_id[i])
      # if(filename == "lens/src/main/java/org/apache/zeppelin/lens/LensJLineShellComponent.java"){
      #   temp = paste(filename, tid, rd2, sep = " ")
      #   print(temp)
      # }
      if(has.key(filename, itvh)){
        for(k in 1:(length(itvh[[filename]]) / 2)){
          if(itvh[[filename]][2 * k - 1] <= rd2 && itvh[[filename]][2 * k] >= rd2){
            a1 = df_file$name_id[i]
            bug_label[i] <- 1
            break
          }
        }
      }
    }
    # 获得bug标签列
    df_file$bug = bug_label

    # 存入文件
    if (!dir.exists(saved_common)){
      dir.create(saved_common)
    }
    # saved_file = paste(saved_common,fileName_metrics,sep = "/")
    # write.table(df_file, saved_file, row.names = FALSE, sep = ",")
  }
}
#===end===#

