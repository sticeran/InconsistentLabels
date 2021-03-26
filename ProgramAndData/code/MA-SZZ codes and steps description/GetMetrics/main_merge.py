'''
定义3个类别: (1)dormant(2)mislabeling_FP(3)collision
(3)指在标签传播过程中，对于代码完全一致的类，标签发生多次改变的现象，如1 0 0 1 0 0(从右往左看)。
记录改变次数，对于改变次数>=2的全部当作噪音抛掉
bug标签：0代表无bug，1代表有bug
'''

import pandas as pd
import step1_3.getFileList as GFL
import step1_3.fileNameSorting as FNS

#'\'需替换成'/'
def function_separatorSubstitution(x):
    return x.replace("\\", "/");

#取度量的时候会受内部类的影响，会生成多个相同文件名的情况，所以需要过滤。
#明天改改这里
if __name__ == "__main__":

#     dataset_style = "jira";
#     dataset_style = "jureczko";
#     dataset_style = "zimmermann";
#     dataset_style = "mySZZ";
    path_common = "D:/workspace/mixed-workspace/mySZZ/GetMetrics/";
    
    #项目列表
#     projectName_list = ['activemq'];#调试用
#     projectName_list = ['activemq','camel','derby','groovy','hbase','hive','jruby','lucene','wicket'];
#     projectName_list = ['ant','camel','forrest','log4j','lucene','poi','synapse','velocity','xalan','jedit'];
#     projectName_list = ['eclipse'];
    projectName_list = ["zeppelin","shiro","maven","flume","mahout"];

    #数据集文件共有路径
    changedCommonPath = path_common + "metrics/";
#     originalCommonPath = path_common + "(use)dataSets/" + dataset_style + "/";
    path_saved_common = path_common + "metrics_mergeInnerClass/";
    path_saved_innerClassesPercent = path_common + "metrics_mergeInnerClass/" + "(all)innerClassesPercent.csv";
    
    columns_df = ["name", "metricsMergeBefore_num", "metricsMergeAfter_num", "(metrics)innerClasses_num", "(metrics)inner_percent"];
    list_dic_allRow = [];
    pd.set_option('max_colwidth',200);#设置value的显示长度为200，默认为50
    for i_projectName in projectName_list:
        
        #===获取每个项目udb_cp_csv文件列表===#需要里面的relName信息
        folderName_project_changed = changedCommonPath + i_projectName + '/';
        level = 1;  # 目录层级
        path_initial = folderName_project_changed;  # 在递归时需要计算减去，和初始文件路径名一致
        fileList_changed = [];  # 存储读出的文件
        allFileNum_changed = [0];  # 存储文件总数
        # 获取每个项目udb_cp_csv文件列表
        GFL.getFileList(level, folderName_project_changed, path_initial, fileList_changed, allFileNum_changed);
        print ('总文件数 =', allFileNum_changed);
        fileList_changed = FNS.sort_insert_filename(fileList_changed);#按文件名版本排序，不然顺序不对，比对时可能出错
        print('文件名排序后\n', fileList_changed)
        #===end===#
    
        #===获取原始文件列表===#需要删除对应的含内部类的类
#         folderName_project_original = originalCommonPath + i_projectName + '/';
#         level = 1;  # 目录层级
#         path_initial = folderName_project_original;  # 在递归时需要计算减去，和初始文件路径名一致
#         fileList_original = [];  # 存储读出的文件
#         allFileNum_original = [0];  # 存储文件总数
#         GFL.getFileList(level, folderName_project_original, path_initial, fileList_original, allFileNum_original);
#         print ('总文件数 =', allFileNum_original);
#         fileList_original = FNS.sort_insert_filename(fileList_original);#按文件名版本排序，不然顺序不对，比对时可能出错
#         print('文件名排序后\n', fileList_original)
        #===end===#
        
        for i_allFileNum in range(len(fileList_changed)):
            list_oneRow = [];

            #存储文件名
            path_saved_fileName = path_saved_common + i_projectName + '/' + fileList_changed[i_allFileNum];

            file_changed_current = folderName_project_changed + fileList_changed[i_allFileNum];#需要通过此判断有内部类的数量。changed记录了两个临近版本的代码变化
            df_changed_current = pd.read_csv(file_changed_current);
#             file_original_current = folderName_project_original + fileList_original[i_allFileNum];#当前原始数据集，需要大小
#             df_original_current = pd.read_csv(file_original_current);#需要原始数据集大小

            #取特定的列
            col_name_id = df_changed_current[['name_id']];
            #'\'需替换成'/'。不然会因分隔符不同匹配不上
#             df_changed_current['relName'] = df_changed_current['relName'].apply(lambda row: function_separatorSubstitution(row));
#             df_original_current.rename(columns={'File':'relName'}, inplace = True);#根据字典重命名
            
            #按relName分组统计数量
            series_group = df_changed_current.groupby(['name_id'])['name_id'].count();#Exception: Data must be 1-dimensional
            #series_group是series,转dataframe
            dict_series_group = {'name_id':series_group.index,'numbers':series_group.values};
            df_group = pd.DataFrame(dict_series_group);
#             print(df_group)
            
            #step3：生成合并内部类的udb_cp_csv，因为数据集是.java文件级。
            
            #按照relName求和，会把内部类的数据加到主类中
            #df_sum会不包含'relName'或'className'列，应该是字符串没法相加自动忽略了
            df_temp = df_group[['name_id']];
            df_sum = df_changed_current.groupby('name_id').sum().reset_index(drop=True);#重置索引很重要
            df_merge = pd.concat([df_temp,df_sum], axis=1)
            df_merge.to_csv(path_saved_fileName,index=False);#不保存行索引
            
#             df_group.reset_index(drop=True,inplace=True);#重置索引很重要，不然取行时会出错
#             df_group['className'] = '';#新增className列，存含内部类的主类名
#             for i in range(len(df_group)):
#                 df_temp = df_changed_current[df_changed_current['relName'] == df_group.loc[i,'relName']];
#                 df_temp.reset_index(drop=True,inplace=True);#要重置行索引，不然用0，1作行下标会出错
#                 df_group.loc[i,'className'] = df_temp.loc[0,'className'];#只取第一个主类，作为类名
#             
#             df_temp_2 = pd.DataFrame(df_group,columns = ['relName','className']);#取需要的列
#             #合并求和数字列df_sum和非数字列的'relName','className'
#             df_merge = pd.concat([df_temp_2, df_sum], axis=1);
#             df_merge.to_csv(path_saved_fileName,index=False);#不保存行索引

            #step3：并统计各个step2生成的(use)dataSets中的数据集内部类占比。
            df_group_inner = df_group[df_group['numbers']>1];#拥有内部类的.java文件行
#             df_inner_intersection = pd.merge(df_group_inner, df_original_current, on='relName', how='inner');#需和原数据集取交，因为原数据集是项目中的部分类
            #结果加入list
            len_udjMergeBefore = len(df_changed_current);#合并前的项目(udj)文件数量
            len_udjMergeAfter = len(df_merge);#合并内部类后的项目(udj)文件数量
#             len_dataSet = len(df_original_current);#step2的数据集文件数量
            len_inner_udj = len(df_group_inner);#udj含内部类文件数量
#             len_inner = len(df_inner_intersection);#dataSet含内部类文件数量
            percent_inner = len_inner_udj / len_udjMergeBefore;#dataSet内部类占比
            list_oneRow.append(fileList_changed[i_allFileNum]);#文件名
            list_oneRow.append(len_udjMergeBefore);#合并前的项目(udj)文件数量
            list_oneRow.append(len_udjMergeAfter);#合并内部类的项目(udj)文件数量
#             list_oneRow.append(len_dataSet);#step2的数据集文件数量
            list_oneRow.append(len_inner_udj);#udj含内部类文件数量
#             list_oneRow.append(len_inner);#dataSet含内部类文件数量
            list_oneRow.append(percent_inner);#dataSet内部类占比
            #和列名生成字典，加入list
            dic_oneRow = dict(zip(columns_df,list_oneRow));
            list_dic_allRow.append(dic_oneRow);
            
    df_allInnerClassesPercent = pd.DataFrame(list_dic_allRow);# 根据字典创建dataframe
    df_allInnerClassesPercent.to_csv(path_saved_innerClassesPercent,index=False,columns=columns_df);#不保存行索引。columns=columns_df的作用是按列顺序存
    print("finish")








