library(boot)

# 技术组合
list_technique = c("RF_NON_NON","RF_CFS_NON","RF_GR_NON","RF_NON_SMOTE","RF_CFS_SMOTE","RF_GR_SMOTE",
                   "NB_NON_NON","NB_CFS_NON","NB_GR_NON","NB_NON_SMOTE","NB_CFS_SMOTE","NB_GR_SMOTE",
                   "LR_NON_NON","LR_CFS_NON","LR_GR_NON","LR_NON_SMOTE","LR_CFS_SMOTE","LR_GR_SMOTE")
# list_technique = c("RF_CFS_SMOTE")

# # 预测场景
# list_scenario_style = c("CVDP", "CPDP")
# # 数据集名字
# list_list_datasetPath = list(c("ECLIPSE-2007","Metrics-Repo-2010","JIRA-HA-2019","JIRA-RA-2019","MA-SZZ-2020"),
#                              c("Metrics-Repo-2010","JIRA-HA-2019","JIRA-RA-2019","MA-SZZ-2020"))

list_scenario_style = c("CVDP")
list_list_datasetPath = list(c("ECLIPSE-2007","Metrics-Repo-2010","JIRA-HA-2019","JIRA-RA-2019","MA-SZZ-2020","IND-JLMIV+R-2020"))

# # 调试用
# list_scenario_style = c("CPDP")
# list_list_datasetPath = list(c("MA-SZZ-2020"))

# 不一致标签率
list_filteringMethod = c('IL_Ins')


# 存储文件名
saved_prefix = "(diff)"
# 读取文件名
list_read_fileName_comparison = c("(comparison)datapoints_filtered.csv")
list_read_fileName_benchmark = c("(benchmark)datapoints_filtered.csv")

# 组合模式名
list_combinedPatterns = c("NC vs CC")
# 评价指标
columns_targetIndicator = c('F1', 'AUC', 'ER','RI','MCC','AP','RR','Popt', 'ACC')
# 存储列名
columns_resultNames = c('Dataset', columns_targetIndicator)
# 中间结果读取路径前缀
path_common_read = "D:/workspace/DataFolder/data_csv/TSILI/results/question2/(all)techniques"
# 结果存储路径
path_result_saved = "D:/workspace/DataFolder/data_csv/TSILI/results/question2/(data)table"




#===置信度调整函数===#
ciAdjustLevel <- function(eta0, conf_level) {
  cl = 1 - (1 - eta0) * (1 - conf_level)
  return(cl)
}
#===end===#

#===boot需要的函数===#
fc<-function(d, i){
  d2 <- d[i]
  return(mean(d2))
}
#===end===#

#===主函数体===#

# 设置种子
set.seed(12345)

# bootstrap可以生成置信度值(默认0.95，或调整后的置信度值)的置信区间，如果0在区间内，不能拒绝零假设；否则，拒绝零假设
for (i_technique in list_technique)
{
  for (i_scenario_style in 1:length(list_scenario_style))
  {
    for (i_filteringMethod in list_filteringMethod)
    {
      scenario_style = list_scenario_style[i_scenario_style]
      list_dataset_style = list_list_datasetPath[[i_scenario_style]]
      
      list_allRows = c()#存储
      for (i in 1:length(list_combinedPatterns))
      {
        # 当前组合模式名
        i_combinedPatterns = list_combinedPatterns[i]
        
        # 首先，为每个指标，根据获得的各个数据集的p值调整p值
        list_p_adjust_allIndicators = c()#每行存储的是，一个指标对应的6个数据集调整后的p值
        for (i_targetIndicator in columns_targetIndicator)
        {
          vector_p = c()
          for (i_dataset_style in 1:length(list_dataset_style))
          {
            dataset_style = list_dataset_style[i_dataset_style]
            # 要读取的结果文件的公共路径
            path_common = paste(path_common_read, 
                                i_technique, scenario_style, dataset_style, sep = "/")
            
            i_read_fileName_comparison = list_read_fileName_comparison[i]
            i_read_fileName_benchmark = list_read_fileName_benchmark[i]
            
            file_comparison = paste(path_common,i_combinedPatterns,i_filteringMethod,i_read_fileName_comparison,sep = '/')# 对比数据集路径
            file_benchmark = paste(path_common,i_combinedPatterns,i_filteringMethod,i_read_fileName_benchmark,sep = '/')# 基准数据集路径
            # 数据集
            df_file_comparison = read.table(file=file_comparison, header=TRUE, sep=",")
            df_file_benchmark = read.table(file=file_benchmark, header=TRUE, sep=",")
            
            # 求comparison和benchmark之间的pgr值
            vector_comparison = df_file_comparison[,i_targetIndicator]#用[,列名]得到的是向量，用[列名]得到的是df
            vector_benchmark = df_file_benchmark[,i_targetIndicator]
            
            data <- abs((vector_comparison-vector_benchmark)/vector_benchmark)*100
            data = data[!is.na(data)]
            data = data[!is.infinite(data)]
            mean_current = round(mean(data),2)
            sd_current = round(sd(data),2)
            
            data2 = round(data,6)
            len_unique = length(unique(data2))
            
            if(len_unique==1){
              p_value <- 1
            } else {
              # bootstarp抽样1000次
              output <- boot(data, fc, R=1000)
              data_boot = output$t
              # 单样本威尔森符号秩检验计算p值
              wilcox <- wilcox.test(data_boot, mu=0, alternative = "two.sided",)
              p_value <- wilcox$p.value
            }
            vector_p = c(vector_p,p_value)
          }
          vector_p_adjust <- p.adjust(vector_p, method = "BH")
          list_p_adjust_allIndicators <- c(list_p_adjust_allIndicators, list(vector_p_adjust))
        }
        
        # 其次，根据调整后的p值，计算置信度值，进而求得置信区间
        for (i_dataset_style in 1:length(list_dataset_style))
        {
          dataset_style = list_dataset_style[i_dataset_style]
          # 要读取的结果文件的公共路径
          path_common = paste(path_common_read, 
                              i_technique, scenario_style, dataset_style, sep = "/")
          # 存储路径
          path_saved_common = paste(path_result_saved,i_technique,"diff_pgr", sep = "/")
          saved_fileName = paste(saved_prefix,scenario_style,".csv",sep = "")
          path_saved_fileName = paste(path_saved_common, saved_fileName, sep = "/")
          
          i_read_fileName_comparison = list_read_fileName_comparison[i]
          i_read_fileName_benchmark = list_read_fileName_benchmark[i]
          
          file_comparison = paste(path_common,i_combinedPatterns,i_filteringMethod,i_read_fileName_comparison,sep = '/')# 对比数据集路径
          file_benchmark = paste(path_common,i_combinedPatterns,i_filteringMethod,i_read_fileName_benchmark,sep = '/')# 基准数据集路径
          # 数据集
          df_file_comparison = read.table(file=file_comparison, header=TRUE, sep=",")
          df_file_benchmark = read.table(file=file_benchmark, header=TRUE, sep=",")
          
          #当数据集，所有指标放一行
          vector_mean_oneRow = c()
          vector_sd_oneRow = c()
          # vector_bcaMin_oneRow = c()
          # vector_bcaMax_oneRow = c()
          vector_confidenceInterval = c()
          for (i_targetIndicator_index in 1:length(columns_targetIndicator))
          {
            i_targetIndicator = columns_targetIndicator[i_targetIndicator_index]
            # 求comparison和benchmark之间的diff值
            vector_comparison = df_file_comparison[,i_targetIndicator]#用[,列名]得到的是向量，用[列名]得到的是df
            vector_benchmark = df_file_benchmark[,i_targetIndicator]
            
            data <- abs((vector_comparison-vector_benchmark)/vector_benchmark)*100
            data = data[!is.na(data)]
            data = data[!is.infinite(data)]
            mean_current = round(mean(data),2)
            sd_current = round(sd(data),2)
            
            data2 = round(data,6)
            len_unique = length(unique(data2))
            
            if(len_unique==1){
              bcaMin_current = data[1]
              bcaMax_current = data[1]
              confidenceInterval = paste('[',bcaMin_current,',',bcaMax_current,']',sep = "")
            } else {
              # bootstarp抽样1000次
              output <- boot(data, fc, R=1000)
              # 获得调整后的p值
              list_p_adjust <- list_p_adjust_allIndicators[[i_targetIndicator_index]]
              p_adjust <- list_p_adjust[i_dataset_style]
              # 根据获得的p值，调整置信度（默认的置信度是0.95），使得置信度更严格（更高）
              conf_level = 0.95
              conf_level_adj = ciAdjustLevel(p_adjust,conf_level)
              # conf_level_adj = 0.95
              # 根据调整后的置信度，计算置信区间
              ci_current = boot.ci(boot.out = output, conf = conf_level_adj, type = c("norm", "basic", "perc", "bca"))
              bca_current = ci_current$bca
              bcaMin_current = round(bca_current[length(bca_current)-1],2)
              bcaMax_current = round(bca_current[length(bca_current)],2)
              confidenceInterval = paste('[',bcaMin_current,',',bcaMax_current,']',sep = "")
            }
            vector_mean_oneRow = c(vector_mean_oneRow,mean_current)
            vector_sd_oneRow = c(vector_sd_oneRow,sd_current)
            # vector_bcaMin_oneRow = c(vector_bcaMin_oneRow,bcaMin_current)
            # vector_bcaMax_oneRow = c(vector_bcaMax_oneRow,bcaMax_current)
            vector_confidenceInterval = c(vector_confidenceInterval,confidenceInterval)
          }
          vector_mean_oneRow <- c(dataset_style,vector_mean_oneRow)
          vector_sd_oneRow <- c(dataset_style,vector_sd_oneRow)
          # vector_bcaMin_oneRow <- c(dataset_style,vector_bcaMin_oneRow)
          # vector_bcaMax_oneRow <- c(dataset_style,vector_bcaMax_oneRow)
          vector_confidenceInterval <- c(dataset_style,vector_confidenceInterval)
          
          names(vector_mean_oneRow) <- columns_resultNames#给vector_oneRow中的元素命名
          names(vector_sd_oneRow) <- columns_resultNames#给vector_oneRow中的元素命名
          # names(vector_bcaMin_oneRow) <- columns_resultNames#给vector_oneRow中的元素命名
          # names(vector_bcaMax_oneRow) <- columns_resultNames#给vector_oneRow中的元素命名
          names(vector_confidenceInterval) <- columns_resultNames#给vector_oneRow中的元素命名
          
          list_allRows = c(list_allRows, list(vector_mean_oneRow))
          list_allRows = c(list_allRows, list(vector_sd_oneRow))
          # list_allRows = c(list_allRows, list(vector_bcaMin_oneRow))
          # list_allRows = c(list_allRows, list(vector_bcaMax_oneRow))
          list_allRows = c(list_allRows, list(vector_confidenceInterval))
        }
      }
      # lst <- list(a = c(A=1,B=2,C=3), b = c(A=4,B=5,C=6), c = c(A=7,B=8,C=9))
      # aa = do.call(cbind,lst)#不能直接得到df
      # bbb <- dplyr::bind_rows(lst)#不显式行拼接仍是列拼接
      # Note that for historical reasons, lists containing vectors are
      # always treated as data frames. Thus their vectors are treated as
      # columns rather than rows, and their inner names are ignored:
      # You can circumvent that behaviour with explicit splicing:
      df_allRows = dplyr::bind_rows(!!!list_allRows)
      
      # 将3种组合模式的两个模型之间（如NN vs. NC）的每个数据集所有版本的评价指标的p值和cliff delta值计算结果存入结果文件
      if (!dir.exists(path_saved_common)){
        dir.create(path_saved_common, recursive = TRUE)
      }
      write.table(df_allRows,path_saved_fileName, row.names = FALSE, col.names = TRUE, sep = ",")
      
      print("finish")
    }
  }
}
#===end===#


# set.seed(12345)
# 
# fc<-function(d, i){
#   d2 <- d[i]
#   return(mean(d2))
# }
# 
# data <- abs((nc$ACC-cc$ACC)/cc$ACC)*100
# 
# output <- boot(data, fc, R=1000)
# boot.ci(boot.out = output, type = c("norm", "basic", "perc", "bca"))
# 
# mean(data)
# sd(data)