import step1_3.getFileList as GFL
import step1_3.fileNameSorting as FNS
import mySZZ.getMetrics.pythonCallperl as CALL
import os

# 从udb文件通过perl脚本抽取度量
if __name__ == "__main__":
#     dataset_style = "jira";
#     dataset_style = "jureczko";
#     dataset_style = "zimmermann";

#     projectName_list = ["kafka","flink","rocketmq","zookeeper","zeppelin","beam","shiro","maven","flume"];
#     projectName_list = ["rocketmq","zeppelin","shiro","maven","flume"];#调试用
#     projectName_list = ["zeppelin","shiro","maven","flume","mahout"];
    projectName_list = ["mahout"];

    path_common = "D:/workspace/mixed-workspace/mySZZ/GetMetrics/";
    commonPath_udb = path_common + "udb/";# 根据项目源码生成的udb文件
    commonPath_saved = path_common + "metrics/";# 存储路径的公有路径。根据源码对应的udb文件，调用perl，判断临近版本修改情况的csv文件
    
    for i_projectName in projectName_list:
        
        #---调用用perl写的度量抽取程序，从udb抽取度量---#
        folderName_project = commonPath_udb + i_projectName + "/";
        folderName_project_savedCsv = commonPath_saved + i_projectName + "/";
        level = 1;  # 目录层级
        path_initial = folderName_project;  # 在递归时需要计算减去，和初始文件路径名一致
        fileList = [];  # 存储读出的文件
        allFileNum = [0];  # 存储文件总数
        # 获取每个项目udb文件列表
        GFL.getFileList(level, folderName_project, path_initial, fileList, allFileNum);
        print ('总文件数 =', allFileNum);
        
        fileList = FNS.sort_insert_filename(fileList);#按文件名版本排序
        print('文件名排序后\n', fileList)
         
        for i_allFileNum in range(0, allFileNum[0]):
            file_parameter = folderName_project + fileList[i_allFileNum];#Db
            outPutFile = folderName_project_savedCsv + os.path.splitext(fileList[i_allFileNum])[0] + ".csv";#outPutFile
            print(fileList[i_allFileNum]+" begin");
            CALL.callCP(file_parameter, outPutFile);#需要2个参数
            print(fileList[i_allFileNum]+" finish");
        #---end---#
#         i_allFileNum=allFileNum[0]-1
#         file_parameter = folderName_project + fileList[i_allFileNum];#Db
#         outPutFile = folderName_project_savedCsv + os.path.splitext(fileList[i_allFileNum])[0] + ".csv";#outPutFile
#         print(fileList[i_allFileNum]+" begin");
#         CALL.callCP(file_parameter, outPutFile);#需要2个参数
#         print(fileList[i_allFileNum]+" finish");
        
    print("finish");

    
    
    
    
    