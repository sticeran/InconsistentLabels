#-*- coding:utf-8 -*-

import sys
import os
import pandas as pd
import numpy as np
import time
# need import understand, and set PYTHONPATH of the UNDERSTAND tool
sys.path.append(r'C:\SciTools\bin\pc-win64\Python')#Installation path of the UNDERSTAND tool
import understand#If PYTHONPATH is set correctly, the import statement will run correctly even if an error is reported in the IDE.


pd.set_option('display.max_columns', None)
pd.set_option('display.max_rows', None)
pd.set_option('max_colwidth',200)
np.set_printoptions(threshold=np.inf)


# Label comparison
# According to the code comparison result of FUNCTION_getEquivalancePartition_bool, determine whether labels are inconsistent labels.
def FUNCTION_labelComparison(twoDimensionalArray_sameCodeVersions_bool,array_labels_allVersions,array_versionNum_allVersions):
    # Examples for testing
#     twoDimensionalArray_sameCodeVersions_bool = np.array([[ True, False, False,  True, False,  True],
#      [False,  True, False, False,  True, False],
#      [False, False, False, False, False, False],
#      [False, False, False, False, False, False],
#      [False, False, False, False, False, False],
#      [False, False, False, False, False, False]])
#     array_labels_allVersions = np.array([1,1,0,0,1,1])
    
    list_versionSet_IL = []
    for i_row_bool in twoDimensionalArray_sameCodeVersions_bool:
        array_labels_i_row = array_labels_allVersions[i_row_bool];
        if array_labels_i_row.size:
            if not ((array_labels_i_row == 1).all() or (array_labels_i_row == 0).all()):
                list_versionSet_IL_oneVersionSet = array_versionNum_allVersions[i_row_bool]
                list_versionSet_IL.append(list_versionSet_IL_oneVersionSet);
    return list_versionSet_IL;
    
# Code comparison
# Judging which versions of each cross-version module have the same code is equivalent to dividing equivalence classes.
def FUNCTION_getEquivalancePartition_bool(X1):
    # Examples for testing
    # Suppose the code (string) of X1 on five versions is as follows:
    # X1=['string_1','string_2','string_1','string_2','string_1']
    # X1=['aa','ab','ac','aa','ab','aa']
    
    num_versions = len(X1)
    array_bool_X1 = np.zeros((num_versions, num_versions), dtype=bool)
    array_bool_notFinded = np.ones(num_versions, dtype = bool)
    
    for i in range(0,num_versions):
        if array_bool_notFinded[i]:
            string_first_file = X1[i];
            for j in range(i+1,num_versions):
                string_second_file = X1[j];
                if string_first_file == string_second_file:
                    array_bool_notFinded[i] = False;
                    array_bool_notFinded[j] = False;
                    array_bool_X1[i][i] = True;
                    array_bool_X1[i][j] = True;
    return array_bool_X1;

# Filter comments, whitespace, and blank lines in the code (.udb file) of a module
def FUNCTION_getFilteredCode(fileEntity):
    sEnt = fileEntity;
    
    str_codeOneFile = '';
    
    file=startLine=endLine='';
    
    if sEnt.kind().check("file"):
        file = sEnt;
        # The line numbers corresponding to the beginning and end of the module in the file
        startLine = 1;
        endLine = sEnt.metric(["CountLine"])["CountLine"];
    else:
        file = sEnt.ref().file();
        # The line numbers corresponding to the beginning and end of the module in the file
        startRef = sEnt.refs("definein","",True)[0];
        endRef = sEnt.refs("end","",True)[0];
        startLine = startRef.line();
        endLine = endRef.line();
    
    # The lexical stream pointer for the file
    lexer = file.lexer();
    
    # The token stream pointer of the module (content from the start line to the end line)
    lexemes = lexer.lexemes(startLine, endLine);

    length = len(lexemes);
    while (length == 0):
        endLine = endLine - 1;
        lexemes = lexer.lexemes(startLine, endLine);
        length = len(lexemes);
    
    # Is the current token in the middle of multiple consecutive white spaces
    in_whitespace = 0;
    
    # Scan backward from the first token in turn, and replace the consecutive blank characters with a space, and the other contents remain unchanged
    for lexeme in lexemes:
        # If the current token is white space (including comments, spaces, and line breaks)
        if ( lexeme.token() == "Comment" or lexeme.token() == "Whitespace" or lexeme.token() == "Newline"):
            # If it is the first white space character
            if not in_whitespace:
                # Add a white space to the result string
                str_codeOneFile = str_codeOneFile + "";
                # Remember a white space that has been encountered
                in_whitespace = 1;
        else:#If it is not a white space character
            str_codeOneFile = str_codeOneFile + lexeme.text();
            in_whitespace = 0;
        
    return str_codeOneFile;

# Search the corresponding file entity according to the relname of cross-version module
def FUNCTION_searchCrossVersionInstance_special(db,searchFileName,InstanceID_udbType):
    if InstanceID_udbType == 'file':
        allfiles = db.ents("file ~unknown ~unresolved");
        for file in allfiles:
            if file.relname().find(searchFileName)!=-1:
                return file;
    if InstanceID_udbType == 'class':
        allfiles = db.ents('class ~unknown ~unresolved, interface ~unknown ~unresolved');
        for file in allfiles:
            if file.longname().find(searchFileName)!=-1:
                return file;

# Search the corresponding file entity according to the relname of cross-version module
def FUNCTION_searchCrossVersionInstance(db,searchFileName,InstanceID_udbType):
    if InstanceID_udbType == 'file':
        allfiles = db.ents("file ~unknown ~unresolved");
        for file in allfiles:
            if file.relname() == searchFileName:
                return file;
    if InstanceID_udbType == 'class':
        allfiles = db.ents('class ~unknown ~unresolved, interface ~unknown ~unresolved');
        for file in allfiles:
            if file.longname() == searchFileName:
                return file;
            
# Read the code in the .udb file
def FUNCTION_readModuleCode(fileUdbPath_i_version,i_crossVersionModule,InstanceID_udbType,dataset_style):
    # Open Database
    db = understand.open(fileUdbPath_i_version);
    
    # Find the file entity corresponding to the cross-version module from the .udb file
    if dataset_style == 'IND-JLMIV+R-2020':
        fileEntity = FUNCTION_searchCrossVersionInstance_special(db,i_crossVersionModule,InstanceID_udbType);
    else:
        fileEntity = FUNCTION_searchCrossVersionInstance(db,i_crossVersionModule,InstanceID_udbType);
    # Filter comments, blanks, and blank lines of code in the module
    str_codeOneFile = FUNCTION_getFilteredCode(fileEntity);
    # close database
    db.close();
    
    return str_codeOneFile;

# For the specific dataset used, the file name needs to be normalized, otherwise the corresponding module may not be found in the downloaded project code.
def FUNCTION_ReverseHandleSpecialProject(i_crossVersionModule,projectName,versionNumber):
    #需要减去"src"前缀的项目列表
    list_projectName_needPrefix1 = ["commons-jcs","commons-jexl","commons-bcel","commons-beanutils","commons-codec","commons-collections","commons-compress","commons-configuration","commons-digester",
                                    "commons-io","commons-lang","commons-net","commons-validator","giraph","jspwiki","santuario-java","systemml","tika","wss4j","nutch"];#根据交集结果，统计需要加src的项目
    #需要减去"deltaspike"前缀的项目列表
    list_projectName_needPrefix2 = ["deltaspike"];
    #需减去"src\\main"前缀的项目版本列表
    list_projectSpecificVersion_needPrefix1 = ["commons-math-1.0","commons-math-1.1","commons-math-1.2"];
    #需减去"src"前缀的项目版本列表
    list_projectSpecificVersion_needPrefix2 = ["commons-math-2.0","commons-math-2.1","commons-math-2.2","commons-math-3.0","commons-math-3.1",
                                    "commons-math-3.2","commons-math-3.3","commons-math-3.4","commons-math-3.5","commons-math-3.6"];
    #需要逆统一变更路径
    list_projectName_changePath1 = ["commons-beanutils-1.9.0"];
    list_projectName_changePath2 = ["commons-collections-4.0","commons-collections-4.1"];
    list_projectName_changePath3 = ["commons-configuration-2.0","commons-configuration-2.1","commons-configuration-2.2"];
    list_projectName_changePath4 = ["commons-digester-3.0","commons-digester-3.1","commons-digester-3.2"];
    list_projectName_changePath5 = ["commons-jexl-3.0","commons-jexl-3.1"];
    list_projectName_changePath6 = ["commons-lang-3.0","commons-lang-3.1","commons-lang-3.2","commons-lang-3.3","commons-lang-3.4","commons-lang-3.5","commons-lang-3.6","commons-lang-3.7"];
    list_projectName_changePath7 = ["commons-math-3.0","commons-math-3.1","commons-math-3.2","commons-math-3.3","commons-math-3.4","commons-math-3.5","commons-math-3.6"];
    
    #需要逆统一变更路径
    project_version = projectName + '-' + versionNumber;
    if project_version in list_projectName_changePath1:
        i_crossVersionModule = i_crossVersionModule.replace('src\\','main\\',1);#替换开头处 
    elif project_version in list_projectName_changePath2:
        i_crossVersionModule = i_crossVersionModule.replace('\\collections\\','\\collections4\\',1);
    elif project_version in list_projectName_changePath3:
        i_crossVersionModule = i_crossVersionModule.replace('\\configuration\\','\\configuration2\\',1);
    elif project_version in list_projectName_changePath4:
        i_crossVersionModule = i_crossVersionModule.replace('\\digester\\','\\digester3\\',1);
    elif project_version in list_projectName_changePath5:
        i_crossVersionModule = i_crossVersionModule.replace('\\jexl2\\','\\jexl3\\',1);
    elif project_version in list_projectName_changePath6:
        i_crossVersionModule = i_crossVersionModule.replace('\\lang\\','\\lang3\\',1);
    elif project_version in list_projectName_changePath7:
        i_crossVersionModule = i_crossVersionModule.replace('\\math\\','\\math3\\',1);
    
    #需要增加前缀
    if projectName in list_projectName_needPrefix1:
        string_added = "src\\";
        string_started = "java\\";
        string_started_2 = "main\\";
        string_started_3 = "share\\";
        string_started_4 = "plugin\\";
        startSubscript = len(string_added);
        length_string_started = len(string_started)+startSubscript;
        length_string_started_2 = len(string_started_2)+startSubscript;
        length_string_started_3 = len(string_started_3)+startSubscript;
        length_string_started_4 = len(string_started_4)+startSubscript;
        if i_crossVersionModule[startSubscript:length_string_started] == string_started \
        or i_crossVersionModule[startSubscript:length_string_started_2] == string_started_2 \
        or i_crossVersionModule[startSubscript:length_string_started_3] == string_started_3 \
        or i_crossVersionModule[startSubscript:length_string_started_4] == string_started_4:
            i_crossVersionModule = i_crossVersionModule.replace(string_added,'',1);#替换开头处 
    elif projectName in list_projectName_needPrefix2:
        string_added = "deltaspike\\";
        i_crossVersionModule = i_crossVersionModule.replace(string_added,'',1);#替换开头处 
    
    if project_version in list_projectSpecificVersion_needPrefix1:
        string_added = "src\\main\\";
        i_crossVersionModule = i_crossVersionModule.replace(string_added,'',1);#替换开头处 
    elif project_version in list_projectSpecificVersion_needPrefix2:
        string_added = "src\\";
        i_crossVersionModule = i_crossVersionModule.replace(string_added,'',1);#替换开头处 
    
    return i_crossVersionModule;
    
# Add the letter 'V' to the version number to avoid storing 0.1 and 0.10 as 0.1
def FUNCTION_getVersionNumber(fileName):
    str_sep= "-";
    str_suffix=".udb";
    delimiter_sep = fileName.rfind(str_sep);#匹配字符串最后一次出现的位置
    delimiter_suffix = fileName.find(str_suffix);
    version = 'v' + fileName[delimiter_sep+1:delimiter_suffix];#得到版本号
    return version;

# Store the defect label data set after taking the intersection of module and instance, and calculate the intersection proportion of module and instance
def FUNCTION_savedIntersection(df_labels_currentVersion,df_intersection,path_common_labels_saved,i_fileLabels):
    list_oneRow = [];
    # storage Path
    dir_path_saved_fileName = path_common_labels_saved + i_projectName + '/';
    if not os.path.exists(dir_path_saved_fileName):
        os.makedirs(dir_path_saved_fileName)
    path_saved_fileName =dir_path_saved_fileName + i_fileLabels;
    
    df_intersection.to_csv(path_saved_fileName,index=False);
    
    len_original = len(df_labels_currentVersion);
    len_intersection = len(df_intersection_labels);
    percent_intersection = len_intersection / len_original;
    list_oneRow.append(i_fileLabels);
    list_oneRow.append(len_original);
    list_oneRow.append(len_intersection);
    list_oneRow.append(percent_intersection);
    
    return list_oneRow;#Return calculation results

# Take the intersection of modules in the source code and instances in the defect dataset
def FUNCTION_takeIntersection(df_udb_currentVersion,df_labels_currentVersion,InstanceID):
    if dataset_style == "Metrics-Repo-2010":#The instance name in this dataset is class and requires special processing
        # Group by 'className'
        series_group = df_udb_currentVersion.groupby(['className'])['className'].count();
        dict_series_group = {'className':series_group.index,'numbers':series_group.values};
        df_group = pd.DataFrame(dict_series_group);
        # Discard the 'classname' with numbers > 1, because a classname may correspond to multiple relnames of different paths,
        # that is, there are classes with the same name in different paths. Therefore, it is necessary to discard them because it is not known which path the classname corresponds to.
        df_group = df_group[df_group['numbers']==1];#选择与relName唯一对应的行，抛掉不唯一对应的行
        df_group = df_group[['className']];
        df_udb_currentVersion = pd.merge(df_group, df_udb_currentVersion, on='className', how='inner');
    
    # Take the intersection of modules in the source code and instances in the defect dataset
    df_col1 = df_labels_currentVersion[[InstanceID,'bug']];
    df_intersection_udb = pd.merge(df_udb_currentVersion, df_col1, on=InstanceID, how='inner');
    df_col2 = df_udb_currentVersion[[InstanceID]];
    df_intersection_labels = pd.merge(df_labels_currentVersion, df_col2, on=InstanceID, how='inner');
    
    return (df_intersection_udb,df_intersection_labels);

# For the specific dataset used, the file name needs to be normalized, otherwise the corresponding module may not be found in the downloaded project code.
def FUNCTION_HandleSpecialProject(df,projectName,str_versionNumber):
    #需要加"src"前缀的项目列表
    list_projectName_needPrefix1 = ["commons-jcs","commons-jexl","commons-bcel","commons-beanutils","commons-codec","commons-collections","commons-compress","commons-configuration","commons-digester",
                                    "commons-io","commons-lang","commons-net","commons-validator","giraph","jspwiki","santuario-java","systemml","tika","wss4j","nutch",]#根据交集结果，统计需要加src的项目
    #需要加"deltaspike"前缀的项目列表
    list_projectName_needPrefix2 = ["deltaspike"];
    #需要加"src\\main"前缀的项目版本列表
    list_projectSpecificVersion_needPrefix1 = ["commons-math-1.0","commons-math-1.1","commons-math-1.2"];
    #需要加"src"前缀的项目版本列表
    list_projectSpecificVersion_needPrefix2 = ["commons-math-2.0","commons-math-2.1","commons-math-2.2","commons-math-3.0","commons-math-3.1",
                                    "commons-math-3.2","commons-math-3.3","commons-math-3.4","commons-math-3.5","commons-math-3.6"];
    #需要统一变更路径
    list_projectName_changePath1 = ["commons-beanutils-1.9.0"];
    list_projectName_changePath2 = ["commons-collections-4.0","commons-collections-4.1"];
    list_projectName_changePath3 = ["commons-configuration-2.0","commons-configuration-2.1","commons-configuration-2.2"];
    list_projectName_changePath4 = ["commons-digester-3.0","commons-digester-3.1","commons-digester-3.2"];
    list_projectName_changePath5 = ["commons-jexl-3.0","commons-jexl-3.1"];
    list_projectName_changePath6 = ["commons-lang-3.0","commons-lang-3.1","commons-lang-3.2","commons-lang-3.3","commons-lang-3.4","commons-lang-3.5","commons-lang-3.6","commons-lang-3.7"];
    list_projectName_changePath7 = ["commons-math-3.0","commons-math-3.1","commons-math-3.2","commons-math-3.3","commons-math-3.4","commons-math-3.5","commons-math-3.6"];
    
    #需要统一变更路径，因为前后两个相邻版本的路径变了，会导致没有同名实例。
    versionNumber = str_versionNumber[1:];
    project_version = projectName + '-' + versionNumber;
    if project_version in list_projectName_changePath1:
        df['relName'] = df['relName'].apply(lambda row: row.replace('main\\','src\\'));    
    elif project_version in list_projectName_changePath2:
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\collections4\\','\\collections\\'));
    elif project_version in list_projectName_changePath3:
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\configuration2\\','\\configuration\\'));
    elif project_version in list_projectName_changePath4:
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\digester3\\','\\digester\\'));
    elif project_version in list_projectName_changePath5:
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\jexl3\\','\\jexl2\\'));
    elif project_version in list_projectName_changePath6:
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\lang3\\','\\lang\\'));
    elif project_version in list_projectName_changePath7:
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\math3\\','\\math\\'));
    
    #需要增加前缀
    if projectName in list_projectName_needPrefix1:
        string_added = "src\\";
        string_started = "java\\";
        string_started_2 = "main\\";
        string_started_3 = "share\\";
        string_started_4 = "plugin\\";
        length_string_started = len(string_started);
        length_string_started_2 = len(string_started_2);
        length_string_started_3 = len(string_started_3);
        length_string_started_4 = len(string_started_4);
        for i_instance in range(len(df)):
            cellName = df.loc[i_instance,'relName'];
            if cellName[0:length_string_started] == string_started \
            or cellName[0:length_string_started_2] == string_started_2 \
            or cellName[0:length_string_started_3] == string_started_3 \
            or cellName[0:length_string_started_4] == string_started_4:
                df.loc[i_instance,'relName'] = ''.join([string_added, cellName]);
    elif projectName in list_projectName_needPrefix2:
        string_added = "deltaspike\\";
        for i_instance in range(len(df)):
            cellName = df.loc[i_instance,'relName'];
            df.loc[i_instance,'relName'] = ''.join([string_added, cellName]);
    
    if project_version in list_projectSpecificVersion_needPrefix1:
        string_added = "src\\main\\";
        for i_instance in range(len(df)):
            cellName = df.loc[i_instance,'relName'];
            df.loc[i_instance,'relName'] = ''.join([string_added, cellName]);
    elif project_version in list_projectSpecificVersion_needPrefix2:
        string_added = "src\\";
        for i_instance in range(len(df)):
            cellName = df.loc[i_instance,'relName'];
            df.loc[i_instance,'relName'] = ''.join([string_added, cellName]);
    
    return df;

#原始缺陷数据集中的特定项目的路径需要变更，不然会和udb中的模块没有交集。
def FUNCTION_HandleSpecialProject_label(df,projectName,str_versionNumber):
    #需要加"src\\main"前缀的项目版本列表
    list_projectSpecificVersion_needPrefix1 = ["commons-math-1.0","commons-math-1.1","commons-math-1.2"];
    #需要统一变更路径，因为前后两个相邻版本的路径变了，会导致没有同名实例。
    versionNumber = str_versionNumber[1:];
    project_version = projectName + '-' + versionNumber;
    if project_version in list_projectSpecificVersion_needPrefix1:
        df['relName'] = df['relName'].apply(lambda row: row.replace('src\\','src\\main\\'));
    return df;

# If the defect label is a count label, it will be changed to 0, 1 binary label
def FUNCTION_changeToLabel(x):
    if x > 0:
        return 1;
    else:
        return 0;

def FUNCTION_separatorSubstitution(x):
    return x.replace("/", "\\");

def FUNCTION_substring(x):
    return x[1:];

# Unify the column name of different defect data sets, which can be adjusted and expanded as needed
def FUNCTION_unifyColumnNames(df_file_original,dataset_style):
    if dataset_style == "Metrics-Repo-2010":
        df_file_original.rename(columns={'name.1':'className'}, inplace=True);
        df_file_original.drop(['name','version'], axis=1, inplace=True);
    elif dataset_style == "JIRA-HA-2019":
        df_file_original.rename(columns={'File':'relName','CountLineCode':'loc','HeuBugCount':'bug'}, inplace=True);
        df_file_original['relName'] = df_file_original['relName'].apply(lambda row: FUNCTION_separatorSubstitution(row));
        df_file_original = df_file_original.drop(['HeuBug','RealBug','RealBugCount'], axis=1);
    elif dataset_style == "JIRA-RA-2019":
        df_file_original.rename(columns={'File':'relName','CountLineCode':'loc','RealBugCount':'bug'}, inplace=True);
        df_file_original['relName'] = df_file_original['relName'].apply(lambda row: FUNCTION_separatorSubstitution(row));
        df_file_original = df_file_original.drop(['HeuBug','RealBug','HeuBugCount'], axis=1);
    elif dataset_style == "ECLIPSE-2007":
        df_file_original.rename(columns={'filename':'relName','TLOC':'loc','post':'bug'}, inplace=True);
        df_file_original['relName'] = df_file_original['relName'].apply(lambda row: FUNCTION_substring(row));
        df_file_original['relName'] = df_file_original['relName'].apply(lambda row: FUNCTION_separatorSubstitution(row));
        df_file_original = df_file_original.drop(['plugin','pre'], axis=1);
        cols = df_file_original.columns.tolist();
        cols.remove('bug');
        cols.append('bug');
        df_file_original = df_file_original[cols];
    elif dataset_style == "MA-SZZ-2020":
        df_file_original.rename(columns={'name_id':'relName'}, inplace=True);
    elif dataset_style == "IND-JLMIV+R-2020":
        df_file_original['relName'] = df_file_original['relName'].apply(lambda row: FUNCTION_separatorSubstitution(row));
    if dataset_style != "IND-JLMIV+R-2020":
        #===To calculate the bug density, the ranking indicators need to use the bug density===#
        df_file_original['bugDensity'] = df_file_original['bug']/df_file_original['loc'];
        df_file_original.fillna(0, inplace=True);
        df_file_original['bug'] = df_file_original['bug'].apply(lambda x: FUNCTION_changeToLabel(x));
        #===end===#
    return df_file_original;

# Read and preprocess the original defect dataset
def FUNCTION_readLabelsDatasets(fileLabelsPath_currentVersion,dataset_style):
    df_file_original = pd.read_csv(fileLabelsPath_currentVersion);
    df_file_original = FUNCTION_unifyColumnNames(df_file_original,dataset_style);
    return df_file_original;

# The inner classes are removed so that the modules in the source code can correspond to the instances in the defect data set one by one
def FUNCTION_removeRedundantInnerClasses(list_information_oneVersion):
    # to genarate dataframe
    columns_name = ['relName','className','version','filePath'];
    df_oneVersion = pd.DataFrame(list_information_oneVersion,columns=columns_name);
    # Delete the duplicate relname, that is, delete the redundant inner class
    df_de_duplication = df_oneVersion.drop_duplicates(subset=['relName'], keep='first');
    
    #---The following optional improvements are to be updated in the future---#
#     # The following procedure only serves the Metrics-Repo-2010 dataset
#     df_de_duplication_copy = df_de_duplication.copy()
#     
#     #===Determine the relname of the inner class in the dataframe===#
#     # group by relName
#     series_group = df_oneVersion.groupby(['relName'])['relName'].count();#Exception: Data must be 1-dimensional
#     dict_series_group = {'relName':series_group.index,'numbers':series_group.values};
#     df_group = pd.DataFrame(dict_series_group);
#     #===end===#
#     
#     #===Select the correct 'classname' for each 'relname'===#
#     list_includeInnerClassesRelName = df_group[df_group['numbers'] != 1]['relName'].tolist();
#     for i_innerRelName in list_includeInnerClassesRelName:
#         list_innerClassName = df_oneVersion[df_oneVersion['relName'] == i_innerRelName]['className'].tolist();
#         index_start = i_innerRelName.rfind('\\')+1;
#         index_end = i_innerRelName.rfind('.');
#         mainClassName = i_innerRelName[index_start:index_end];
#         
#         for j_className in list_innerClassName:
#             index_start = j_className.rfind('.')+1;
#             one_innerClassName = j_className[index_start:];
#             if one_innerClassName == mainClassName:
#                 index_rel = df_de_duplication[df_de_duplication['relName'] == i_innerRelName].index.tolist()[0];
#                 df_de_duplication_copy.loc[index_rel,'className'] = j_className;
#                 break;
#     #===end===#
#     df_de_duplication_copy.reset_index(drop=True,inplace=True);
#     return df_de_duplication_copy;
    #---end---#
    
    df_de_duplication.reset_index(drop=True,inplace=True);
    return df_de_duplication;


# Read .udb file, get the file name, class name, version number and file path
def FUNCTION_readFileList(db_class,verision):
    # Store pre returned information,
    # Each line stores file name, class name, version number and file path
    list_information_allRows = []
    
    # Open Database
    db = understand.open(db_class)
    
    # get class entities list
    tempclasses = db.ents("class ~unknown ~unresolved");
    filterClasses = [];
    for i_class in tempclasses:
        if i_class.library() == "Standard":
            continue;
        if i_class.ref("definein", "interface"):
            continue;
        if i_class.ref("definein", "class"):
            continue;
        if i_class.ref("definein", "method"):
            continue;
        if i_class.ref("definein", "function"):
            continue;
        startRef = i_class.refs("definein","",True); 
        endRef = i_class.refs("end","",True);        
        if (not startRef or not endRef):
            continue;
        filterClasses.append(i_class)
    
    tempInterfaces = db.ents("interface ~unknown ~unresolved");
    for i_interface in tempInterfaces:
        if i_interface.library()  == "Standard":
            continue;
        filterClasses.append(i_interface)
    
    for i_class in filterClasses:
        # push info about this class on to the array
        classlongname = i_class.longname()
        relname = i_class.ref().file().relname()
        filelongname = i_class.ref().file().longname()
        list_information_allRows.append([relname,classlongname,verision,filelongname])
    
    # close database
    db.close();
    
    # return file name and class name
    return list_information_allRows;
    
    

if __name__ == '__main__':
    # dataset name
    dataset_style = "Metrics-Repo-2010";
    # project list
    projectName_list = ['ant','camel','forrest','jedit','log4j','lucene','pbeans','poi','synapse','velocity','xalan','xerces'];
    
    # read path of module (.udb) 
    path_common = "D:/TSILI/udb/" + dataset_style + "/";
    # read path of original defect data set
    path_common_labels = "D:/TSILI/original/" + dataset_style + "/";
    # storage path for the intersection of project modules and defect data set instances
    path_common_labels_saved = "D:/TSILI/(intersected)dataSets/" + dataset_style + "/";
    # storage path of inconsistent label detection results of TSILI algorithm
    path_common_results_IL_saved = "D:/TSILI/(TSILI)inconsistentLabel/" + dataset_style + "/";
    saved_fileName_intersectionStatistics = "(all)intersectionStatistics.csv";
    saved_fileName_results_IL = "filenameList.csv";
    
    
    # Stores the intersection of modules and instances of all versions of all projects
    list_intersectionInformation_allProjectsVersions = [];
    # Traverse all projects in the dataset
    for i_projectName in projectName_list:
        begin_time = time.perf_counter()
        # TSILI: input
        # The read path of the project
        folderName_project = path_common + i_projectName + "/";
        fileUdbList = os.listdir(folderName_project);#List of .udb file names for all versions
        fileUdbList = fileUdbList[1:];#The first file stores the code corresponding to .udb files. Filter out this folder, and the rest is the .udn files corresponding to all versions
        #Original defect dataset path
        folderName_project_labels = path_common_labels + i_projectName + '/';
        fileLabelsList = os.listdir(folderName_project_labels);
        
        #---stage 1: Generate an information table recording instances in all versions---#
        # b1
        # moduleInfo: <name, version, codePath, defectLabel>
        moduleInfo_df = pd.DataFrame(columns = ['relName','className','version','codePath']);
        if dataset_style == "Metrics-Repo-2010":
            InstanceID = 'className';
            InstanceID_udbType = 'class';
        else:
            InstanceID = 'relName';
            InstanceID_udbType = 'file';
        # b2
        # For each version, read the module in the .udb file and the instance in the defect data set, and take the intersection of the two
        for i_fileUdb,i_fileLabels in zip(fileUdbList,fileLabelsList):
            # Get the current version number
            str_versionNumber = FUNCTION_getVersionNumber(i_fileUdb)
            # Get the path to the current version of the .udb file
            filePath_currentVersion = folderName_project + i_fileUdb;
            # Read the information of all modules in the current version from a .udb file and store it in four columns: 
            # the first column is the file name, 
            # the second column is the class name, 
            # the third column is the version number, 
            # and the fourth column is the full path to the file.
            SV_i = FUNCTION_readFileList(filePath_currentVersion,str_versionNumber);
            # Preprocessing: remove redundant inner classes, otherwise there may be problems
            SV_i_df = FUNCTION_removeRedundantInnerClasses(SV_i);
            # Get the path to the current version of original defect dataset
            fileLabelsPath_currentVersion = folderName_project_labels + i_fileLabels;
            # Read and preprocess the original defect data set
            DV_i_df = FUNCTION_readLabelsDatasets(fileLabelsPath_currentVersion,dataset_style);
            # b3~b9
            # Take the intersection of modules and instances, and use the intersection of modules and instances to carry out subsequent experiments
            if dataset_style == "IND-JLMIV+R-2020":
                SV_i_df = FUNCTION_HandleSpecialProject(SV_i_df,i_projectName,str_versionNumber);
                DV_i_df = FUNCTION_HandleSpecialProject_label(DV_i_df,i_projectName,str_versionNumber);
            (df_intersection_udb,df_intersection_labels) = FUNCTION_takeIntersection(SV_i_df,DV_i_df,InstanceID);
            # Store the intersection of module and instance, and count the intersection proportion information
            list_intersectionInformation_oneRow = FUNCTION_savedIntersection(DV_i_df,df_intersection_labels,path_common_labels_saved,i_fileLabels);
            # The statistical information of intersection is added to the list
            list_intersectionInformation_allProjectsVersions.append(list_intersectionInformation_oneRow);
            # The intersection of modules and instances is stored in a globally maintained moduleInfo table
            moduleInfo_df = pd.concat([moduleInfo_df, df_intersection_udb], axis=0);
        # b10: i = i + 1
        # b11
        moduleInfo_df.reset_index(drop=True,inplace=True);
        # Add the 'isInconsistentLabel' column to moduleinfo, and change it into to quintuple < name, version, codePath, defectLabel, isIncinstantLabel>
        # Initialize the 'isInconsistentLabel' column with a value of 'NO', indicating non-inconsistent label
        moduleInfo_df['isInconsistentLabel'] = 'NO';
        #---end---#
         
        #---stage 2-1: Find out the cross-version modules---#
        # b1
        # group by relName and count the number of each group. If the number is greater than 1, it indicates that a module appears on multiple versions, whether continuous or not
        series_group = moduleInfo_df.groupby([InstanceID])[InstanceID].count();#Exception: Data must be 1-dimensional
        dict_series_group = {InstanceID:series_group.index,'numbers':series_group.values};
        df_group = pd.DataFrame(dict_series_group);
        # Get cross-version modules with more than 1 versions
        df_crossVersionModules= df_group[df_group['numbers'] != 1]
        list_name_crossVersionModules = df_crossVersionModules[InstanceID].tolist();
        df_crossVersionModules_information = pd.merge(df_crossVersionModules, moduleInfo_df, on=InstanceID, how='left');
        #---end---#
        
        #---stage 2-2: For each cross-version module, the module code is compared globally first, and then the defect labels are compared. Assign the 'isInconsistentLabel' of the found instance with inconsistent label to 'yes'---#
        m = len(list_name_crossVersionModules);
        # b2
        for i in range(m):
            # b3
            # Get the current cross-version module
            i_crossVersionModule = list_name_crossVersionModules[i];
            df_i_crossVersionModule_rows = df_crossVersionModules_information[df_crossVersionModules_information[InstanceID]==i_crossVersionModule];
            # Get all the version numbers of the current cross-version module
            list_versionNum_allVersions_i_crossVersionModule = df_i_crossVersionModule_rows['version'].tolist();
            array_versionNum_allVersions = np.array(list_versionNum_allVersions_i_crossVersionModule)
            # b4
            # get labelSet(Gets the label set of the current cross-version module)
            list_labelSet = df_i_crossVersionModule_rows['bug'].tolist();
            labelSet_array = np.array(list_labelSet);
            # b5
            # Judge whether the defect labels on all versions are the same. If all of them are the same, the detection of inconsistent labels will be skipped.
            if not ((labelSet_array == 1).all() or (labelSet_array == 0).all()):
                # b6
                # Get the code on all versions of the current cross-version module
                codeInfo_filtered_list = [];
                # b7~b9
                for j_version_i_crossVersionModule in list_versionNum_allVersions_i_crossVersionModule:
                    versionNumber = j_version_i_crossVersionModule[1:];
                    udb_i_version = i_projectName + '-' + versionNumber + '.udb';
                    # Get the .udb file path of the current version
                    fileUdbPath_i_version = path_common + i_projectName + "/" + udb_i_version;
                    # Get the code of the current cross version module on each version, and filter the comments, white spaces and blank lines
                    if dataset_style == "IND-JLMIV+R-2020":
                        i_crossVersionModule_originalName = FUNCTION_ReverseHandleSpecialProject(i_crossVersionModule,i_projectName,versionNumber);
                        str_codeOneFile = FUNCTION_readModuleCode(fileUdbPath_i_version,i_crossVersionModule_originalName,InstanceID_udbType,dataset_style);
                    else:
                        str_codeOneFile = FUNCTION_readModuleCode(fileUdbPath_i_version,i_crossVersionModule,InstanceID_udbType,dataset_style);
                    codeInfo_filtered_list.append(str_codeOneFile);
                # b11
                # Find out which versions of cross module have the same code and return the two-dimensional bool array with the same code
                twoDimensionalArray_sameCodeVersions_bool = FUNCTION_getEquivalancePartition_bool(codeInfo_filtered_list);
                # b12~b18
                # On found versions that have the same code, judge whether the defect labels on these versions are the same, and return the version numbers of inconsistent labels
                list_versionSet_IL = FUNCTION_labelComparison(twoDimensionalArray_sameCodeVersions_bool,labelSet_array,array_versionNum_allVersions);
                # On the found version with inconsistent labels, assign 'isInconsistentLabel' to 'yes'
                for i_versionSet_IL in list_versionSet_IL:
                    for i_version_IL in i_versionSet_IL:
                        index_IL = moduleInfo_df[(moduleInfo_df[InstanceID]==i_crossVersionModule) & (moduleInfo_df['version']==i_version_IL)].index.tolist()[0];
                        # b17 Set inconsistent label
                        moduleInfo_df.loc[index_IL,'isInconsistentLabel'] = 'YES';
        # b19: i = i + 1
         
        # Store the globally maintained table moduleInfo, where moduleInfo is the detection result of inconsistent labels, 
        # and the 'isInsinstentLabel' attribute indicates whether the label of an instance is inconsistent label
        dir_path_saved = path_common_results_IL_saved + i_projectName + "/";
        if not os.path.exists(dir_path_saved):
            os.makedirs(dir_path_saved)
        path_saved_fileName = dir_path_saved + saved_fileName_results_IL;
        moduleInfo_df.to_csv(path_saved_fileName,index=False);
         
        end_time = time.perf_counter()
        run_time = end_time-begin_time
        print ('running time:',run_time)
        #---end---#
    
    # Store intersection information of modules and instances on all projects and all versions
    df_intersectionInformation_allProjectsVersions = pd.DataFrame(list_intersectionInformation_allProjectsVersions,columns=["name", "original_length", "intersection_length", "percent"]);
    dir_path_saved = path_common_labels_saved;
    if not os.path.exists(dir_path_saved):
        os.makedirs(dir_path_saved)
    path_saved_fileName = dir_path_saved + saved_fileName_intersectionStatistics;
    df_intersectionInformation_allProjectsVersions.to_csv(path_saved_fileName,index=False);
    print("finish");
    
    
    
    
    
    
    
    
    
    
    
    
    