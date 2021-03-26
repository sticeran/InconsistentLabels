
library("DMwR")
library("FSelector")
library(randomForest)
library(e1071)#naiveBayes函数
library(klaR)#klaR函数包使用,在e1071包的基础上进行的扩展
library(caret)#计算逻辑回归模型的度量重要性需要的包
library(pROC)
library(ROSE)
library(vip)

#跨版本预测，用当前版本之前的版本（一个或多个）建模，预测下个版本（新版本）
#跨项目预测，用其余项目所有版本建模，预测目标项目（的一个版本）
# list_scenario_style = c("CVDP", "CPDP")
# list_list_datasetPath = list(c("ECLIPSE-2007","Metrics-Repo-2010","JIRA-HA-2019","JIRA-RA-2019","MA-SZZ-2020"),
#                              c("Metrics-Repo-2010","JIRA-HA-2019","JIRA-RA-2019","MA-SZZ-2020"))
list_scenario_style = c("CVDP")
list_list_datasetPath = list(c(
                                "ECLIPSE-2007",
                                "Metrics-Repo-2010",
                                "JIRA-HA-2019",
                                "JIRA-RA-2019",
                                "MA-SZZ-2020",
                                "IND-JLMIV+R-2020"))

#实验用的数据集中，已去掉buggy实例数<=10的版本
l1 = list(
          c('eclipse'),
          c('ant','camel','jedit','log4j','lucene','pbeans','poi','synapse','velocity','xalan','xerces'),
          c('activemq','camel','derby','groovy','hbase','hive','jruby','lucene','wicket'),
          c('activemq','camel','derby','groovy','hbase','hive','jruby','lucene','wicket'),
          c("zeppelin","shiro","maven","flume","mahout"),
          c('ant-ivy','calcite','knox','kylin','mahout','manifoldcf','nutch','systemml','tika'))
# l2 = list(c('ant','camel','jedit','log4j','lucene','pbeans','poi','synapse','velocity','xalan','xerces'),
#           c('activemq','camel','derby','groovy','hbase','hive','jruby','lucene','wicket'),
#           c('activemq','camel','derby','groovy','hbase','hive','jruby','lucene','wicket'),
#           c("zeppelin","shiro","maven","flume","mahout"))


#生成NC和CC两种模型
list_data_style = list(c("cleanData","cleanData"),c("noiseData","cleanData"))
list_savedResult_style = c("clean_clean","noise_clean")

#===调试用===#
# list_list_datasetPath = list(c("IND-JLMIV+R-2020"))
# l1 = list(
#           c('manifoldcf','nutch','systemml','tika'))
# list_scenario_style = c("CVDP", "CPDP")
# list_list_datasetPath = list(c("MA-SZZ-2020"),c("MA-SZZ-2020"))
# l1 = list(c("zeppelin","shiro","maven","flume","mahout"))
# l2 = list(c("zeppelin","shiro","maven","flume","mahout"))

# list_data_style = list(c("noiseData","cleanData"))
# list_savedResult_style = c("noise_clean")
# list_list_datasetPath = list(c("Metrics-Repo-2010","JIRA-HA-2019","JIRA-RA-2019","MA-SZZ-2020"),
#                              c("Metrics-Repo-2010","JIRA-HA-2019","JIRA-RA-2019","MA-SZZ-2020"))
# l1 = list(c('ant','camel','jedit','log4j','lucene','pbeans','poi','synapse','velocity','xalan','xerces'),
#           c('activemq','camel','derby','groovy','hbase','hive','jruby','lucene','wicket'),
#           c('activemq','camel','derby','groovy','hbase','hive','jruby','lucene','wicket'),
#           c("zeppelin","shiro","maven","flume","mahout"))
#===end===#

#使用的分类器
classifierName = "RF"
# classifierName = "NB"
# classifierName = "LR"
#使用的特征选择技术
# featureSelectionName = "NON"
# featureSelectionName = "CFS"
featureSelectionName = "GR"
#使用的不平衡技术
# rebalancingName = "NON"
rebalancingName = "SMOTE"

# 要读取的数据集文件的公共路径
path_common = "D:/workspace/DataFolder/data_csv/TSILI/experimentDataset"

#存储路径的公共路径
saved_common_all = "D:/workspace/DataFolder/data_csv/TSILI/results/(all)techniques"

# 计算Popt和ACC时，需要计算bug密度，已在数据集中添加了bug密度


#===获得训练的模型中的度量重要性===#
doGetImportance <- function(classifier_classification,df_training_fs)
{
  #对于caret包训练的分类器而言，可以不指定feature_names参数，对于其他包训练的分类器需要指定
  cols_df_training_fs = colnames(df_training_fs)
  subscript_bug = which(cols_df_training_fs == "bug")
  cols_fs = cols_df_training_fs[-subscript_bug]
  #如果特征数等于1，vi_permute方法无法正常计算
  if (length(cols_fs)==1){
    metric_importance <- data.frame(metric=cols_fs,importance=1)
  } else {
    metric_importance <- vi_permute(classifier_classification,feature_names=cols_fs,target=df_training_fs$bug,metric="accuracy",pred_wrapper=predict)
  }
  df_metric_importance = as.data.frame(metric_importance)
  cnames = c('metric','importance')
  colnames(df_metric_importance) = cnames
  return(df_metric_importance)
}
#===end===#

#===分类指标计算===#
doClassificationEvaluation <- function(classifier_rf_classification,df_test)
{
  # df_test$bug = factor(df_test$bug)#记得分类标签因子化，不然做的是回归
  # 特征选择后
  pred1=predict(classifier_rf_classification,df_test)# type可以是"response","prob","vote",分别表示输出预测向量是预测类别、预测概率或投票矩阵
  
  # 计算accuracy,precision,recall,F1
  Freq1 = table(pred1,df_test$bug)#得到混淆矩阵
  accuracy = sum(diag(Freq1))/sum(Freq1)
  if((Freq1[2] + Freq1[4]) != 0) {
    precision = Freq1[4]/(Freq1[2] + Freq1[4])
  } else {
    precision = 0
  }
  if((Freq1[3] + Freq1[4]) != 0) {
    recall = Freq1[4]/(Freq1[3] + Freq1[4])
  } else {
    recall = 0
  }
  if(precision != 0 || recall != 0) {
    F1 = 2*precision*recall/(precision + recall)
  } else {
    F1 = 0
  }
  
  TP = Freq1[4]
  FP = Freq1[2]
  TN = Freq1[1]
  FN = Freq1[3]
  
  x = TP + FP
  y = TP
  n=TP+FN
  N=TP+FP+FN+TN
  
  ER = (y*N-x*n)/(y*N)
  RI = (y*N-x*n)/(x*n)
  
  vector_result = c(accuracy,precision,recall,F1,ER,RI)
  
  # 将预测结果和评价指标计算结果一起返回
  pre_indicator = list(pred1,vector_result)
  
  # return(vector_result)
  return(pre_indicator)
}
#===end===#

#===排序指标计算===#
doRankingEvaluation <- function(classifier_rf_ranking,df_test_density)
{
  len_columns = length(df_test_density)
  df_test = df_test_density[,1:(len_columns-2)]
  # 特征选择后
  pred1=predict(classifier_rf_ranking,df_test,type="prob")# type可以是"response","prob","vote",分别表示输出预测向量是预测类别、预测概率或投票矩阵
  pred1=pred1[,2]
  
  # 把预测结果和真实标签绑定
  # 这里要判断，如果已经有loc，则会有两个loc，留需要的，删掉不需要的
  data = cbind(df_test_density,pred1)
  # 按照概率降序排序
  data <- data[order(-data$pred1), ]
  
  #把工作路径设置到path
  path = "D:/workspace/R-workspace/thirdPaper"
  setwd(path)
  source("rankingIndicator.r")
  
  # 计算AUC
  roc1 = roc(df_test$bug,pred1,levels=c(1,0))
  auc1 = auc(roc1)
  # plot(roc1,print.auc=T, auc.polygon=T, grid=c(0.1, 0.2), grid.col=c("green","red"), max.auc.polygon=T, auc.polygon.col="skyblue",print.thres=T)
  # 计算MAP,MRR
  MAP = ComputeMAP(data)
  MRR = ComputeMRR(data)
  # 计算Popt,ACC
  Popt = ComputePopt(data,sorted <- TRUE)
  ACC = ComputeACC(data,sorted <- TRUE)
  
  vector_result = c(auc1,MAP,MRR,Popt,ACC)
  
  # 将预测结果和评价指标计算结果一起返回
  pre_indicator = list(pred1,vector_result)
  
  # return(vector_result)
  return(pre_indicator)
}
#===end===#

#===分类和排序指标计算===#
doPerformanceEvaluation <- function(classifier_classification,df_test_density)
{
  len_columns = length(df_test_density)
  df_test = df_test_density[,1:(len_columns-2)]#后两列是缺陷密度和代码行，除工作量指标外，其余指标不需要
  pred=predict(classifier_classification,df_test,type="prob")# type可以是"raw"/"response","prob","vote",分别表示输出预测向量是预测类别、预测概率或投票矩阵
  pred1 = data.frame(pred)
  pred1$bug = vector(mode="numeric",length=nrow(pred1))
  cnames = c('prob_0','prob_1','bug')
  colnames(pred1) = cnames
  pred1$bug[which(pred1$prob_1>=0.5)]=1
  
  # 计算accuracy,precision,recall,F1
  Freq1 = table(pred1$bug,df_test$bug)#得到混淆矩阵
  Freq1 = as.numeric(Freq1)
  if (length(Freq1)!=4) {
    if (length(pred1$bug[which(pred1$bug==1)])==0) {
      Freq1[3] = 0
      Freq1[4] = 0
    } else if(length(pred1$bug[which(pred1$bug==0)])==0) {
      a = Freq1[1]
      b = Freq1[2]
      Freq1[1] = 0
      Freq1[2] = 0
      Freq1[3] = a
      Freq1[4] = b
      print("*************find*************")
    }    
  }
  accuracy = (Freq1[1] + Freq1[4])/sum(Freq1)
  # accuracy = sum(diag(Freq1))/sum(Freq1)
  if((Freq1[2] + Freq1[4]) != 0) {
    precision = Freq1[4]/(Freq1[2] + Freq1[4])
  } else {
    precision = 0
  }
  if((Freq1[3] + Freq1[4]) != 0) {
    recall = Freq1[4]/(Freq1[3] + Freq1[4])
  } else {
    recall = 0
  }
  if(precision != 0 || recall != 0) {
    F1 = 2*precision*recall/(precision + recall)
  } else {
    F1 = 0
  }
  
  TP = Freq1[4]
  FP = Freq1[2]
  TN = Freq1[1]
  FN = Freq1[3]
  
  if(((TP+FP)*(TP+FN)*(TN+FP)*(TN+FN))== 0) {
    MCC = 0
  } else {
    MCC = (TP*TN-FP*FN)/(sqrt((TP+FP)*(TP+FN)*(TN+FP)*(TN+FN)))
  }
  
  x = TP + FP
  y = TP
  n=TP+FN
  N=TP+FP+FN+TN
  
  ER = (y*N-x*n)/(y*N)
  RI = (y*N-x*n)/(x*n)
  
  # 计算AUC,MAP,MRR,Popt,ACC
  # 计算AUC
  prob_buggy = pred1$prob_1
  roc1 = roc(df_test$bug,prob_buggy,levels=c(1,0))
  auc1 = auc(roc1)
  # plot(roc1,print.auc=T, auc.polygon=T, grid=c(0.1, 0.2), grid.col=c("green","red"), max.auc.polygon=T, auc.polygon.col="skyblue",print.thres=T)
  
  # 把预测结果和真实标签绑定
  data = cbind(df_test_density,prob_buggy)
  # 按照概率降序排序
  data <- data[order(-data$prob_buggy), ]
  
  #把工作路径设置到path
  path = "D:/workspace/R-workspace/thirdPaper"
  setwd(path)
  source("rankingIndicator.r")
  
  # 计算AP,RR
  AP = ComputeMAP(data)
  RR = ComputeMRR(data)
  # Popt,ACC的计算，需要标签列是numeric
  data$bug = as.numeric(data$bug)
  # 计算Popt,ACC
  Popt = ComputePopt(data,sorted <- TRUE)
  ACC = ComputeACC(data,sorted <- TRUE)
  
  vector_result = c(accuracy,precision,recall,F1,auc1,ER,RI,MCC,AP,RR,Popt,ACC)
  
  # 将预测结果和评价指标计算结果一起返回
  pre_indicator = list(pred1,vector_result)
  
  # return(vector_result)
  return(pre_indicator)
}
#===end===#

#===随机森林,分类任务===#
doRandomForest_classification <- function(df_file_model)
{
  df_file_model$bug = factor(df_file_model$bug)#记得分类标签因子化，不然做的是回归
  # 特征选择后
  # classifier_rf_classification = randomForest(bug~., data=df_file_model, importance=TRUE)
  classifier_rf_classification = randomForest(bug~., data=df_file_model)
  return(classifier_rf_classification)
}
#===end===#

#===贝叶斯,分类任务===#
doNaiveBayes_classification <- function(df_file_model)
{
  df_file_model$bug = factor(df_file_model$bug)#记得分类标签因子化，不然做的是回归
  classifier_nb_classification =train(bug~.,data=df_file_model,method="naive_bayes")#metric = ifelse(is.factor(y_dat), "Accuracy", "RMSE")自动根据依赖变量来设置的
  return(classifier_nb_classification)
}
#===end===#

#===逻辑回顾,分类任务===#
doLogisticRegression_classification <- function(df_file_model)
{
  df_file_model$bug = factor(df_file_model$bug)#记得分类标签因子化，不然做的是回归
  classifier_lr_classification =train(bug~.,data=df_file_model,method="glm",family=binomial(link="logit"))#metric = ifelse(is.factor(y_dat), "Accuracy", "RMSE")自动根据依赖变量来设置的
  return(classifier_lr_classification)
}
#===end===#

#===根据参数选择分类器===#
FUNCTION_selectClassifier <- function(df_file_model,classifierName)
{
  if(classifierName=="RF"){
    classifier_classification = doRandomForest_classification(df_file_model)
  } else if(classifierName=="NB") {
    classifier_classification = doNaiveBayes_classification(df_file_model)
  } else if(classifierName=="LR") {
    classifier_classification = doLogisticRegression_classification(df_file_model)
  }
  return (classifier_classification)
}
#===end===#

#===训练集使用ROSE处理不平衡===#
doROSE <- function(df_file_current)
{
  table(df_file_current$bug)
  # 注意，ovun.sample()在4.0.0版本以上不能使用，运行会报错。4.0.0版本以上需要使用ROSE()函数
  df_newTrainingData <- ROSE(bug~., data=df_file_current, seed=1)$data
  # df_newTrainingData <- ovun.sample(bug~., data=read.data,
  #                                 p=0.5, 
  #                                 seed=1, method="both")$data
  table(df_newTrainingData$bug)
  return(df_newTrainingData)
}
#===end===#

#===训练集使用SMOTE处理不平衡===#
doSMOTE <- function(df_file_current)
{
  # table(df_file_current$bug)
  
  ## now using SMOTE to create a more "balanced problem"
  df_file_current$bug = factor(df_file_current$bug)
  # df_newTrainingData = SMOTE(bug~., df_file_current, perc.over = a,perc.under=b) #自己设置参数时
  df_newTrainingData = SMOTE(bug~., df_file_current)
  # table(df_newTrainingData$bug)
  return(df_newTrainingData)
}
#===end===#

#===根据参数选择不平衡技术===#
FUNCTION_selectRebalancingTechnique <- function(df_training,rebalancingName)
{
  if(rebalancingName=="ROSE"){
    df_training_c = doROSE(df_training)
  } else if(rebalancingName=="SMOTE") {
    df_training_c = doSMOTE(df_training)#获得SMOTE处理后的测试集,bug是因子，用于分类任务
  } else {
    df_training_c = df_training
  }
  return (df_training_c)
}
#===end===#

#===CFS特征选择===#
doCFS <- function(df_file_current)
{
  columns_subset = cfs(bug~., df_file_current)#特征选择返回子列名
  columns_subset = c(columns_subset,'bug')#增加类别标签列名
  df_temp = subset(df_file_current, select = c(columns_subset)) #根据列名选取子列
  return (df_temp)
}
#===end===#

#===ReliefF特征选择===#
doReliefF <- function(df_file_current)
{
  n_features = ncol(df_file_current)-1
  n_retained = log(n_features,2)
  weights = relief(bug~., df_file_current)#特征选择返回子列名
  columns_subset <- cutoff.k(weights, n_retained)
  columns_subset = c(columns_subset,'bug')#增加类别标签列名
  df_temp = subset(df_file_current, select = c(columns_subset)) #根据列名选取子列
  return (df_temp)
}
#===end===#

#===GainRatio特征选择===#
doGainRatio <- function(df_file_current)
{
  n_features = ncol(df_file_current)-1
  n_retained = ceiling(log(n_features,2))
  weights = gain.ratio(bug~., df_file_current)#特征选择返回子列名
  columns_subset <- cutoff.k(weights, n_retained)
  columns_subset = c(columns_subset,'bug')#增加类别标签列名
  df_temp = subset(df_file_current, select = c(columns_subset)) #根据列名选取子列
  return (df_temp)
}
#===end===#

#===根据参数选择特征选择技术===#
FUNCTION_selectFS <- function(df_training,featureSelectionName)
{
  if(featureSelectionName=="CFS"){
    df_training_s = doCFS(df_training)
  } else if(featureSelectionName=="RE") {
    df_training_s = doReliefF(df_training)
  } else if(featureSelectionName=="GR") {
    df_training_s = doGainRatio(df_training)
  } else {
    df_training_s = df_training
  }
  return (df_training_s)
}
#===end===#

#===log(x+1)变换===#
doLogChange <- function(df_file_current)
{
  df_temp = df_file_current
  columns = length(df_temp)
  for(i in 1:columns)
  {
    df_temp[,i] = log(df_file_current[,i]+1,2)
  }
  return (df_temp)
}
#===end===#

#===预处理训练集和测试集，并预测===#
doPredicting <- function(df_file_model,df_file_prediction,classifierName,featureSelectionName,rebalancingName,iterations)
{
  len_columns = length(df_file_model)
  len_df_rows = nrow(df_file_model)
  
  # 准确率,精确率,召回率,F1
  #直接创建空的dataframe,在rbind时列名会重新随机给，之前的列名会不见。所以这样好点
  #这样产生一行空行，等会通过data = data[-1,]去掉是最好的办法。
  df_results = data.frame(accuracy=c(NA),precision=c(NA),recall=c(NA),F1=c(NA),AUC=c(NA),ER=c(NA),RI=c(NA),MCC=c(NA),AP=c(NA),RR=c(NA),Popt=c(NA),ACC=c(NA))
  #预存储的分类和排序标签列
  predicted_bug_classification = 0#预测的分类标签列
  predicted_bug_probability = 0#预测的排序标签列
  df_label_saved = cbind(df_file_prediction,predicted_bug_classification,predicted_bug_probability)#预存储的dataframen
  df_label_saved = df_file_prediction[1,]#把预存储的dataframen赋空
  df_label_saved = df_label_saved[-1,]#把预存储的dataframen赋空
  
  for(num_iteration in 1:iterations)
  {
    # 设置随机种子为了重现实验结果
    set.seed(12345)
    
    # 跨版本预测，不采用自助法，只进行一次建模和预测
    df_training = df_file_model#训练集
    df_test = df_file_prediction#测试集
    df_test_saved = df_test#记录每次的测试集
    
    # 去掉['bugDensity']列
    originalLoc = df_test$loc#用于工作量感知指标：Popt和ACC
    bugDensity = df_test$bugDensity#用于工作量感知指标：Popt和ACC
    df_training = df_training[,1:(len_columns-1)]
    df_test = df_test[,1:(len_columns-1)]
    df_training <- df_training[,-(1:1)]
    df_test <- df_test[,-(1:1)]
    
    # 对训练集和测试集进行log(x+1)变换。这一步，需要先于SMOTE进行，不然factor因子化后，执行[,i]+1后有问题
    df_training = doLogChange(df_training)
    df_test = doLogChange(df_test)
    
    #分类标签因子化，不然特征选择可能会有问题
    df_training$bug = factor(df_training$bug)
    df_test$bug = factor(df_test$bug)
    
    #根据参数选择不平衡技术
    df_training_rebalance = FUNCTION_selectRebalancingTechnique(df_training,rebalancingName)#获得不平衡处理后的测试集,bug是因子,用于分类任务
    
    #根据参数选择特征选择技术
    df_training_fs = FUNCTION_selectFS(df_training_rebalance,featureSelectionName)
    df_test = df_test[colnames(df_training_fs)]#测试集根据CFS特征选择后的训练集保留列
    df_test_density = cbind(df_test,originalLoc)#用于工作量感知指标的测试：Popt和ACC
    df_test_density = cbind(df_test_density,bugDensity)#用于工作量感知指标的测试：Popt和ACC
    
    #根据参数选择分类器,并训练分类器
    classifier_classification = FUNCTION_selectClassifier(df_training_fs,classifierName)
    
    # 获得度量重要性（训练的模型中）
    df_metric_importance = doGetImportance(classifier_classification,df_training_fs)
    
    # 性能评估，预测的分类标签，预测的有bug的概率，准确率,精确率,召回率,F1,ER,RI,AUC,MAP,MRR,Popt,ACC
    predictedResults = doPerformanceEvaluation(classifier_classification,df_test_density)
    predicted_bug_classification = predictedResults[[1]]$bug# 预测的分类标签
    predicted_bug_probability = predictedResults[[1]]$prob_1# 预测的是buggy标签的概率
    # 记录预测的分类标签和排序概率
    df_test_saved$predicted_bug_classification = predicted_bug_classification
    df_test_saved$predicted_bug_probability = predicted_bug_probability
    # 分类和排序评价指标
    vector_result = predictedResults[[2]]# 准确率,精确率,召回率,F1,AUC,ER,RI,MCC,MAP,MRR,Popt,ACC
    
    # 记录一次bootstrap的结果
    df_results = rbind(df_results,vector_result)#评价指标结果
    df_label_saved = rbind(df_label_saved,df_test_saved)#标签预测结果
    
    # 打印SMOTE前和SMOTE后，训练集数量
    # len_tr_origi = nrow(df_training)
    # len_smote = nrow(df_training_smote)
    # len_c = c("training:",len_tr_origi,"SMOTE:",len_smote)
    # print(len_c)
  }
  df_results <- df_results[-1,]#删除第一行空行
  df_three = list(df_label_saved,df_results,df_metric_importance)
  return(df_three)
}
#===end===#

#===获得原始训练集===#
FUNCTION_generateTrainingSets <- function(path_common_model,train_list_projectName)
{
  bool_theFirst = TRUE
  for (i_projectName in train_list_projectName)
  {
    folderName_project_model = paste(path_common_model,i_projectName, sep = "/")#用作建模的项目路径
    
    fileList_model = list.files(folderName_project_model)#list.files命令得到"folderName_project_model"文件夹下所有文件夹的名称
    # 还需将fileList_model里面的文件排序
    #把工作路径设置到path
    path = "D:/workspace/R-workspace/"
    setwd(path)
    source("fileNameSorting.r")
    fileList_model = sort_bubble_filename(fileList_model)
    
    for (i_file_model in fileList_model)
    {
      file_model = paste(folderName_project_model,i_file_model, sep = "/")#得到用作建模的文件路径
      df_file_model = read.table(file=file_model, header=TRUE, sep=",")
      if (bool_theFirst) {
        #CamargoCruz09转换函数,可以在log里加
        df_file_model_all = df_file_model
        bool_theFirst = FALSE
      } else {
        df_file_model_all = rbind(df_file_model_all,df_file_model)
      }
    }
  }
  return (df_file_model_all)
}
#===end===#

#===生成训练集和测试集，调用预测===#
FUNCTION_generateTrainingSetAndTestSet <- function(scenario_style,dataset_style,classifierName,featureSelectionName,rebalancingName,list_projectName,path_common_model,path_common_prediction,
                                                   path_saved_common_predictedResults,path_saved_common_evaluatingIndicators,
                                                   path_saved_common_metricImportance)
{
  if(scenario_style == "CVDP"){
    for (i_projectName in list_projectName)
    {
      folderName_project_model = paste(path_common_model,i_projectName, sep = "/")#用作建模的项目路径
      folderName_project_prediction = paste(path_common_prediction,i_projectName, sep = "/")#用作预测的项目路径
      
      folderName_project_saved_predictedResults = paste(path_saved_common_predictedResults,i_projectName, sep = "/")#保存预测的分类标签和排序概率的文件夹路径
      folderName_project_saved_evaluatingIndicators = paste(path_saved_common_evaluatingIndicators,i_projectName, sep = "/")#保存评价指标的文件夹路径
      folderName_project_saved_metricImportance = paste(path_saved_common_metricImportance,i_projectName, sep = "/")#保存评价指标的文件夹路径
      
      #===得到该路径下所有文件===#
      fileList_model = list.files(folderName_project_model)#list.files命令得到"folderName_project_model"文件夹下所有文件夹的名称
      # 还需将fileList_model里面的文件排序
      #把工作路径设置到path
      path = "D:/workspace/R-workspace/"
      setwd(path)
      source("fileNameSorting.r")
      fileList_model = sort_bubble_filename(fileList_model)
      #===end===#
      
      #以下关于训练数据的生成方式再修改一下
      #以1.1,1.2,1.3为例，1.3有两种训练集，1.2->1.3;1.1,1.2->1.3
      for (i_file_prediction in 2:length(fileList_model))
      {
        # 当前测试集文件名，如1.3
        i_file_prediction_name = fileList_model[i_file_prediction]
        # 打印当前测试集文件名
        print(i_file_prediction_name)
        # 获取测试集文件路径
        file_prediction = paste(folderName_project_prediction,i_file_prediction_name, sep = "/")#得到用作测试的文件路径
        # 读取测试数据集
        df_file_prediction = read.table(file=file_prediction, header=TRUE, sep=",")
        
        # 对于1.3可能要用不用的训练集建模和预测多次，因此需要一个for循环
        # 拼接存储文件名需要的信息
        len_suffix = 4# ".csv"文件名后缀长度为4
        # 生成保存的文件名路径的初始信息
        temp_prediction_name = substr(i_file_prediction_name, 1, nchar(i_file_prediction_name)-len_suffix)
        i_file_savedName = paste(temp_prediction_name,"(",sep = "")
        if (dataset_style=="IND-JLMIV+R-2020"){
          i_file_savedName_head = i_file_savedName
        }
        # 合并要用到的训练集以及生成存储文件名
        totalNumberOfTrainingFiles = i_file_prediction - 1
        for (current_numberOfTrainingFiles in 1:totalNumberOfTrainingFiles)
        {
          # 拼接存储文件名
          if (dataset_style=="IND-JLMIV+R-2020"){
            i_file_savedName = paste(i_file_savedName_head,current_numberOfTrainingFiles,sep = "")
          } else {
            i_file_savedName = paste(temp_prediction_name,"(",sep = "")
          }
          # 当前训练集有可能有多个文件，因此训练集的df需要拼接
          # 这样产生一行空行，等会通过data = data[-1,]去掉是最好的办法。
          df_file_model = data.frame()
          for (i_file_model in (i_file_prediction-1):((i_file_prediction-1)-(current_numberOfTrainingFiles-1)))
          {
            # 当前训练集名，对于测试集1.3，如1.2+1.1
            i_file_model_name = fileList_model[i_file_model]
            # 获取训练集文件路径
            file_model = paste(folderName_project_model,i_file_model_name, sep = "/")#得到用作建模的文件路径
            # 读取训练数据集
            temp_df_file_model = read.table(file=file_model, header=TRUE, sep=",")
            # 行方向合并训练数据集
            df_file_model = rbind(df_file_model,temp_df_file_model)
            
            # 拼接存储文件名
            if (dataset_style!="IND-JLMIV+R-2020"){
              temp_positions = gregexpr("-",i_file_model_name)[[1]]
              int_startPosition = temp_positions[length(temp_positions)]#"-"字符最后出现的位置
              temp_model_name = substr(i_file_model_name, int_startPosition+1, nchar(i_file_model_name)-len_suffix)
              i_file_savedName = paste(i_file_savedName,temp_model_name,",",sep = "")
            }
          }
          #生成保存的文件名路径
          if (dataset_style!="IND-JLMIV+R-2020"){
            i_file_savedName = substr(i_file_savedName,1,nchar(i_file_savedName)-1)
          }
          i_file_savedName = paste(i_file_savedName,").csv",sep = "")
          file_saved_predictedResults = paste(folderName_project_saved_predictedResults,i_file_savedName, sep = "/")#得到保存预测结果的文件路径
          file_saved_evaluatingIndicators = paste(folderName_project_saved_evaluatingIndicators,i_file_savedName, sep = "/")#得到保存评价指标的文件路径
          file_saved_metricImportance = paste(folderName_project_saved_metricImportance,i_file_savedName, sep = "/")#得到保存度量重要性的文件路径
          
          # 跨版本预测，对于一个训练集，一个测试集，只进行一次预测
          df_three = doPredicting(df_file_model,df_file_prediction,classifierName,featureSelectionName,rebalancingName,iterations = 1)
          df_predictedResults = df_three[[1]]
          df_evaluatingIndicators = df_three[[2]]
          df_metricImportance = df_three[[3]]
          
          # 将预测的结果存入结果文件
          if (!dir.exists(folderName_project_saved_predictedResults)){
            dir.create(folderName_project_saved_predictedResults, recursive = TRUE)
          }
          if (!dir.exists(folderName_project_saved_evaluatingIndicators)){
            dir.create(folderName_project_saved_evaluatingIndicators, recursive = TRUE)
          }        
          if (!dir.exists(folderName_project_saved_metricImportance)){
            dir.create(folderName_project_saved_metricImportance, recursive = TRUE)
          }
          write.table(df_predictedResults,file_saved_predictedResults, row.names = FALSE, col.names = TRUE, sep = ",")
          write.table(df_evaluatingIndicators,file_saved_evaluatingIndicators, row.names = FALSE, col.names = TRUE, sep = ",")
          write.table(df_metricImportance,file_saved_metricImportance, row.names = FALSE, col.names = TRUE, sep = ",")
          
          print("finish")
        }
      }
    }
  } else if(scenario_style == "CPDP") {
    num_i_projectName = 1#当前项目下标，生成训练数据时，项目列表删除当前项目
    for (i_projectName in list_projectName)
    {
      # folderName_project_model = paste(path_common_model,i_projectName, sep = "/")#用作建模的项目路径
      folderName_project_prediction = paste(path_common_prediction,i_projectName, sep = "/")#用作预测的项目路径
      
      folderName_project_saved_predictedResults = paste(path_saved_common_predictedResults,i_projectName, sep = "/")#保存预测的分类标签和排序概率的文件夹路径
      folderName_project_saved_evaluatingIndicators = paste(path_saved_common_evaluatingIndicators,i_projectName, sep = "/")#保存评价指标的文件夹路径
      folderName_project_saved_metricImportance = paste(path_saved_common_metricImportance,i_projectName, sep = "/")#保存评价指标的文件夹路径
      
      #===得到该路径下所有文件===#
      fileList_test = list.files(folderName_project_prediction)#list.files命令得到"folderName_project_prediction"文件夹下所有文件夹的名称
      # 还需将fileList_test里面的文件排序
      #把工作路径设置到path
      path = "D:/workspace/R-workspace/"
      setwd(path)
      source("fileNameSorting.r")
      fileList_test = sort_bubble_filename(fileList_test)
      #===end===#
      
      # 得到训练数据集(跨项目预测)，其余项目的所有版本的文件作为训练数据
      train_list_projectName = list_projectName
      train_list_projectName = train_list_projectName[-num_i_projectName]#项目列表去掉当前项目
      df_file_model = FUNCTION_generateTrainingSets(path_common_model,train_list_projectName)#log转换前的训练集
      
      for (i_file_test in fileList_test)
      {
        # i_file_test = 'log4j-1.2.csv'#调试用
        
        # 打印当前文件名
        print(i_file_test)
        
        # 获取文件路径名
        file_prediction = paste(folderName_project_prediction,i_file_test, sep = "/")#得到用作测试的文件路径（和用作建模的相同文件名的noise或clean的文件路径）
        
        #生成保存的文件名路径
        file_saved_predictedResults = paste(folderName_project_saved_predictedResults,i_file_test, sep = "/")#得到保存预测结果的文件路径
        file_saved_evaluatingIndicators = paste(folderName_project_saved_evaluatingIndicators,i_file_test, sep = "/")#得到保存评价指标的文件路径
        file_saved_metricImportance = paste(folderName_project_saved_metricImportance,i_file_test, sep = "/")#得到保存度量重要性的文件路径
        
        # 得到测试数据集
        # df_file_model = read.table(file=file_model, header=TRUE, sep=",")
        df_file_prediction = read.table(file=file_prediction, header=TRUE, sep=",")#log转换前的测试集
        
        # 跨项目预测，对于一个测试集，使用除自身版本外其余版本和其余项目作为训练集，只进行一次预测
        df_three = doPredicting(df_file_model,df_file_prediction,classifierName,featureSelectionName,rebalancingName,iterations = 1)
        df_predictedResults = df_three[[1]]
        df_evaluatingIndicators = df_three[[2]]
        df_metricImportance = df_three[[3]]
        
        # 将预测的结果存入结果文件
        if (!dir.exists(folderName_project_saved_predictedResults)){
          dir.create(folderName_project_saved_predictedResults, recursive = TRUE)
        }
        if (!dir.exists(folderName_project_saved_evaluatingIndicators)){
          dir.create(folderName_project_saved_evaluatingIndicators, recursive = TRUE)
        }        
        if (!dir.exists(folderName_project_saved_metricImportance)){
          dir.create(folderName_project_saved_metricImportance, recursive = TRUE)
        }
        write.table(df_predictedResults,file_saved_predictedResults, row.names = FALSE, col.names = TRUE, sep = ",")
        write.table(df_evaluatingIndicators,file_saved_evaluatingIndicators, row.names = FALSE, col.names = TRUE, sep = ",")
        write.table(df_metricImportance,file_saved_metricImportance, row.names = FALSE, col.names = TRUE, sep = ",")
        
        print("finish")
      }
      num_i_projectName = num_i_projectName + 1
    }
  }
}
#===end===#

#===主函数体===#
for (i_scenario_style in 1:length(list_scenario_style))
{
  scenario_style = list_scenario_style[i_scenario_style]
  list_dataset_style = list_list_datasetPath[[i_scenario_style]]
  if(scenario_style == "CVDP"){
    list_list_projectName = l1
  } else if(scenario_style == "CPDP") {
    list_list_projectName = l2
  }
  
  allTechniquesName = paste(classifierName,featureSelectionName,rebalancingName, sep = "_")#使用的分类器，特征选择，再平衡技术的名字
  saved_common = paste(saved_common_all,allTechniquesName,scenario_style, sep = "/")#不同场景的公共存储路径
  for (i_data_style in 1:length(list_data_style))
  {
    data_style_model_prediction = unlist(list_data_style[i_data_style])#每个值是两个值的向量数组，分别是用于建模和预测的数量类型的名字
    for (i_dataset_style in 1:length(list_dataset_style))
    {
      dataset_style = list_dataset_style[i_dataset_style]
      list_projectName = list_list_projectName[[i_dataset_style]]
      #获取建模，预测，存储路径
      path_common_model = paste(path_common,dataset_style,data_style_model_prediction[1], sep = "/")#用什么类型建模
      path_common_prediction = paste(path_common,dataset_style,data_style_model_prediction[2], sep = "/")#用什么类型预测
      
      path_saved_common_predictedResults = paste(saved_common,"predictedResults",dataset_style,list_savedResult_style[i_data_style], sep = "/")#存储路径：预测结果
      path_saved_common_evaluatingIndicators = paste(saved_common,"evaluatingIndicators",dataset_style,list_savedResult_style[i_data_style], sep = "/")#存储路径：评价指标
      
      path_saved_common_metricImportance = paste(saved_common,"metricImportance",dataset_style,list_savedResult_style[i_data_style], sep = "/")#存储路径：度量重要性
      
      
      #根据不同场景，产生不同的训练集和测试集，去训练和预测
      FUNCTION_generateTrainingSetAndTestSet(scenario_style,dataset_style,classifierName,featureSelectionName,rebalancingName,list_projectName,path_common_model,path_common_prediction,
                                             path_saved_common_predictedResults,path_saved_common_evaluatingIndicators,
                                             path_saved_common_metricImportance)
    }
  }
}
#===end===#

