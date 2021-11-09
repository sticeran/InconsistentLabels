import subprocess
import os

def generateUdbCommand(undPath,udbPath_saved,sourceCodePath):
    undCommand = undPath + "und create -db " + udbPath_saved + " -languages java add " + sourceCodePath + " analyze -all";
    return undCommand;

# 调用und.exe程序，根据项目名，自动生成udb文件。
if __name__ == "__main__":
    
#     approach_style = "heuristic";
#     approach_style = "realistic";
#     dataset_style = "jira";
#     dataset_style = "jureczko";
#     dataset_style = "zimmermann";
#     dataset_style = "mySZZ";
    dataset_style = "JLMIV";
    path_common = "D:/workspace/DataFolder/ThirdPaper/data_csv/labelPropagation/udb/";
    
    #项目列表
    projectName_list = ['kylin'];#调试用
#     projectName_list = ['activemq','camel','derby','groovy','hbase','hive','jruby','lucene','wicket'];
#     projectName_list = ['ant','camel','forrest','jedit','log4j','lucene','poi','synapse','velocity','xalan'];
#     projectName_list = ['eclipse'];
#     projectName_list = ["zeppelin","shiro","maven","flume","mahout"];
#     projectName_list = ["ant-ivy","archiva","calcite","cayenne","commons-bcel","commons-beanutils","commons-codec","commons-collections","commons-compress","commons-configuration"];
#     projectName_list = ["commons-dbcp",
# "commons-digester",
# "commons-io",
# "commons-jcs",
# "commons-jexl",
# "commons-lang",
# "commons-math",
# "commons-net",
# "commons-scxml",
# "commons-validator",
# "commons-vfs",
# "deltaspike",
# "eagle",
# "giraph",
# "gora",
# "jspwiki",
# "knox",
# "kylin",
# "lens",
# "mahout",
# "manifoldcf",
# "nutch",
# "opennlp",
# "parquet-mr",
# "santuario-java",
# "systemml",
# "tika",
# "wss4j",
# ];
#     projectName_list = ["kylin","nutch","santuario-java","tika"];
    projectName_list = ["nutch","santuario-java","tika"];
    #数据集项目代码文件公共路径
    codeCommonPath = path_common + dataset_style + "/";
    #udb存储路径
    udbCommonPath_saved = path_common + dataset_style + "/";
    #und路径
    undPath = "D:/software/programming_software/data_analysis_tool/Understand/SciTools/bin/pc-win64/";
    
    for i_projectName in projectName_list:
        codeProjectPath = codeCommonPath + i_projectName + "/" + i_projectName + "/";
        dir_udbCommonPath_saved = udbCommonPath_saved + i_projectName + "/";
        files = os.listdir(codeProjectPath);
        if not os.path.exists(dir_udbCommonPath_saved):
            os.makedirs(dir_udbCommonPath_saved)
        for i_file in files:
            if not i_file.endswith('.zip') and not i_file.endswith('.tar.gz'):
                codePath = codeProjectPath + i_file;
                udbPath_saved = dir_udbCommonPath_saved + i_file + '.udb';
                undCommand = generateUdbCommand(undPath,udbPath_saved,codePath);
                #获得应用程序的标准输出（check_output）
                ret=subprocess.check_output(undCommand,shell=True);
    
    print("finish");

    
    
    
    
    