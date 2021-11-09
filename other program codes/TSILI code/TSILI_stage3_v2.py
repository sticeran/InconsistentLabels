import pandas as pd
import os


# If the defect label is a count label, it will be changed to 0, 1 binary label
def FUNCTION_changeToLabel(x):
    if x > 0:
        return 1
    else:
        return 0

def FUNCTION_substring(x):
    return x[1:];

# Add the letter 'V' to the version number to avoid storing 0.1 and 0.10 as 0.1
def FUNCTION_getVersionNumber(fileName):
    str_sep= "-";
    str_suffix=".csv";
    delimiter_sep = fileName.rfind(str_sep);
    delimiter_suffix = fileName.find(str_suffix);
    version = 'v' + fileName[delimiter_sep+1:delimiter_suffix];
    return version;

def FUNCTION_separatorSubstitution(x):
    return x.replace("\\", "/");

# Unify the column name of different defect data sets, which can be adjusted and expanded as needed
def FUNCTION_unifyColumnNames(df_file_original,dataset_style):
    if dataset_style == "Metrics-Repo-2010":
        df_file_original.rename(columns={'name.1':'className'}, inplace=True);
        df_file_original.drop(['name','version'], axis=1, inplace=True);
    elif dataset_style == "JIRA-HA-2019":
        df_file_original.rename(columns={'File':'relName','CountLineCode':'loc','HeuBugCount':'bug'}, inplace=True);
        df_file_original = df_file_original.drop(['HeuBug','RealBug','RealBugCount'], axis=1);
    elif dataset_style == "JIRA-RA-2019":
        df_file_original.rename(columns={'File':'relName','CountLineCode':'loc','RealBugCount':'bug'}, inplace=True);
        df_file_original = df_file_original.drop(['HeuBug','RealBug','HeuBugCount'], axis=1);
    elif dataset_style == "ECLIPSE-2007":
        df_file_original.rename(columns={'filename':'relName','TLOC':'loc','post':'bug'}, inplace=True);
        df_file_original['relName'] = df_file_original['relName'].apply(lambda row: FUNCTION_substring(row));
        df_file_original = df_file_original.drop(['plugin','pre'], axis=1);
        cols = df_file_original.columns.tolist();
        cols.remove('bug');
        cols.append('bug');
        df_file_original = df_file_original[cols];#把'bug'列放到最后去
    elif dataset_style == "MA-SZZ-2020":#原始数据集name_id列也全部是'\'符号，不需要转
        df_file_original.rename(columns={'name_id':'relName'}, inplace=True);
        df_file_original['relName'] = df_file_original['relName'].apply(lambda row: FUNCTION_separatorSubstitution(row));
    elif dataset_style == "IND-JLMIV+R-2020":
        pass;
    #===To calculate the bug density, the ranking indicators need to use the bug density===#
    df_file_original['bugDensity'] = df_file_original['bug']/df_file_original['loc'];
    df_file_original.fillna(0, inplace=True);
    # change the number of bug to the label (0 or 1)
    df_file_original['bug'] = df_file_original['bug'].apply(lambda x: FUNCTION_changeToLabel(x));
    #===end===#
    return df_file_original;



if __name__ == "__main__":
    # dataset name
    list_datasetPath = ["ECLIPSE-2007","Metrics-Repo-2010","JIRA-HA-2019","JIRA-RA-2019","MA-SZZ-2020","IND-JLMIV+R-2020"];
    # project list
    list_list_projectName = [['eclipse'],
                             ['ant','camel','forrest','jedit','log4j','lucene','pbeans','poi','synapse','velocity','xalan','xerces'],
                             ['activemq','camel','derby','groovy','hbase','hive','jruby','lucene','wicket'],
                             ['activemq','camel','derby','groovy','hbase','hive','jruby','lucene','wicket'],
                             ["zeppelin","shiro","maven","flume","mahout"],
                             ["ant-ivy","archiva","calcite","cayenne","commons-bcel","commons-beanutils","commons-codec","commons-collections",
                             "commons-compress","commons-configuration","commons-dbcp","commons-digester","commons-io","commons-jcs","commons-jexl",
                             "commons-lang","commons-math","commons-net","commons-scxml","commons-validator","commons-vfs","deltaspike","eagle",
                             "giraph","gora","jspwiki","knox","kylin","lens","mahout","manifoldcf","nutch","opennlp","parquet-mr","santuario-java","systemml","tika","wss4j",],
                             ];
    
    path_common = "D:/TSILI/";
    # read path of the defect dataset that has detected inconsistent labels using the TSILI approach 
    path_common_IL = path_common + "(TSILI)inconsistentLabel/";
    # read path of original defect data set
    path_common_original = path_common + "original/";
    # read file name
    read_filename_IL = "filenameList.csv";
    # storage path for the pre-updated label attribute of the original defect dataset
    path_common_saved = path_common + "(type)original/";
    
    
    for i_datasetPath,list_projectName in zip(list_datasetPath,list_list_projectName):
        for i_projectName in list_projectName:
            # input (1)
            path_common_dataset = path_common_original + i_datasetPath + '/' + i_projectName + '/';
            fileList = os.listdir(path_common_dataset);
            # input (2)
            fullPath_IL = path_common_IL + i_datasetPath + '/' + i_projectName + '/' + read_filename_IL;
            moduleInfo_df = pd.read_csv(fullPath_IL);
            # b1
            moduleInfo_df['relName'] = moduleInfo_df['relName'].apply(lambda row: FUNCTION_separatorSubstitution(row));            
            # b2
            for i_file in fileList:
                # b3
                str_versionNumber = FUNCTION_getVersionNumber(i_file);
                curModuleInfo_df = moduleInfo_df[moduleInfo_df['version']==str_versionNumber];
                
                # b4~b12
                fullPath_original = path_common_dataset + i_file;
                DV_i_df = pd.read_csv(fullPath_original);
                # Unify the column names of datasets
                DV_i_df = FUNCTION_unifyColumnNames(DV_i_df,i_datasetPath);
                
                if i_datasetPath == "Metrics-Repo-2010":
                    InstanceID = 'className';
                    curModuleInfo_df = curModuleInfo_df[['className','isInconsistentLabel']];
                else:
                    InstanceID = 'relName';
                    curModuleInfo_df = curModuleInfo_df[['relName','isInconsistentLabel']];
                
                df_merge = pd.merge(DV_i_df,curModuleInfo_df,on=[InstanceID],how='left')
                #Because some instances cannot find the corresponding module, the value of 'isInconsistentLabel' in some instances will be NaN
                df_merge.fillna('NAN', inplace=True);

                # Store results
                dir_path_saved = path_common_saved + i_datasetPath + '/' + i_projectName + '/';
                if not os.path.exists(dir_path_saved):
                    os.makedirs(dir_path_saved)
                path_saved_fileName = dir_path_saved + i_file;
                df_merge.to_csv(path_saved_fileName,index=False);
            # b13: i = i + 1
                
    print("finish");




