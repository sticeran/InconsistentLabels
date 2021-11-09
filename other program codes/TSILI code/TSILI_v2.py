#-*- coding:utf-8 -*-

import sys
import os
import pandas as pd
import numpy as np
import time
from collections import deque
import copy
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
    list_projectName_needPrefix1 = ["commons-jcs","commons-bcel","commons-beanutils","commons-codec","commons-compress","commons-digester",
                                    "commons-io","commons-net","systemml","wss4j","nutch"];#根据交集结果，统计需要加src的项目
    #需要减去"deltaspike"前缀的项目列表
    list_projectName_needPrefix2 = ["deltaspike"];
    
    #需要去掉特定字符串之前的前缀
    list_projectName_removePrefix = ["tika-0.1","tika-0.2","tika-0.3"];
    
    #需减去"src\\main"前缀的项目版本列表
    list_projectSpecificVersion_needPrefix1 = ["commons-math-1.0","commons-math-1.1","commons-math-1.2"];
    #需减去"src"前缀的项目版本列表
    list_projectSpecificVersion_needPrefix2 = [
        "commons-configuration-1.0","commons-configuration-1.1","commons-configuration-1.2","commons-configuration-1.3","commons-configuration-1.4","commons-configuration-1.5","commons-configuration-1.6","commons-configuration-1.7",
        "commons-collections-1.0","commons-collections-2.0","commons-collections-2.1","commons-collections-3.0","commons-collections-3.1","commons-collections-3.2","commons-collections-3.3",
        "commons-lang-1.0","commons-lang-2.0","commons-lang-2.1","commons-lang-2.2","commons-lang-2.3","commons-lang-2.4",
        "commons-math-2.0","commons-math-2.1","commons-math-2.2","commons-math-3.0","commons-math-3.1","commons-math-3.2","commons-math-3.3","commons-math-3.4","commons-math-3.5","commons-math-3.6",
        "commons-validator-1.0","commons-validator-1.1.0","commons-validator-1.2.0","commons-validator-1.3.0"];
    #需要减去"giraph-core\\src\\"前缀的项目列表
    list_projectSpecificVersion_needPrefix3 = ["giraph-0.1.0"];
    #需要减去"archiva-modules\\"前缀的项目列表(除4个以"archiva-cli"开头的特定实例外)
    list_projectSpecificVersion_needPrefix4 = ["archiva-1.0"];
    
    #需要逆统一变更路径
    list_projectName_changePath1 = ["commons-beanutils-1.9.0",
                                    "commons-bcel-6.0","commons-bcel-6.1","commons-bcel-6.2",#除这三个版本外，之前的版本不需要加src
                                    "commons-codec-1.6","commons-codec-1.7","commons-codec-1.8","commons-codec-1.9","commons-codec-1.10","commons-codec-1.11",#除这几个版本外，之前的版本需要加src
                                    "commons-io-2.0","commons-io-2.1","commons-io-2.2","commons-io-2.3","commons-io-2.4","commons-io-2.5",
                                    "commons-net-2.0","commons-net-2.1","commons-net-2.2","commons-net-3.0","commons-net-3.1","commons-net-3.2","commons-net-3.3","commons-net-3.4","commons-net-3.5","commons-net-3.6",
                                    ];
    list_projectName_changePath2 = ["santuario-java-2.0.0","santuario-java-2.1.0"];
    list_projectName_changePath3 = ["commons-collections-4.0","commons-collections-4.1"];
    list_projectName_changePath4 = ["commons-configuration-2.0","commons-configuration-2.1","commons-configuration-2.2"];
    list_projectName_changePath5 = ["commons-digester-3.0","commons-digester-3.1","commons-digester-3.2"];
    list_projectName_changePath6 = ["commons-lang-3.0","commons-lang-3.1","commons-lang-3.2","commons-lang-3.3","commons-lang-3.4","commons-lang-3.5","commons-lang-3.6","commons-lang-3.7"];
    list_projectName_changePath7 = ["commons-math-3.0","commons-math-3.1","commons-math-3.2","commons-math-3.3","commons-math-3.4","commons-math-3.5","commons-math-3.6"];
    #需要把以下变更反转
    #需要把"common""cube""dictionary""job""metadata""storage"开头的加上"core-"
    list_projectName_changePath8 = ["kylin-0.6.1","kylin-0.7.1","kylin-1.0.0","kylin-1.1.0","kylin-1.2.0","kylin-1.3.0"];
    #需要把"main\\java\\"变为"src\\share"
    list_projectName_changePath9 = ["commons-validator-1.4.0","commons-validator-1.5.0","commons-validator-1.6.0"]
    #需要把"\\vfs2\\"变为"\\vfs\\"
    list_projectName_changePath10 = ["commons-vfs-2.0","commons-vfs-2.1"]
    #需要把"\\vfs2\\"变为"\\vfs\\"
    #需要把"commons-vfs2\\"变为"core\\"以及"commons-vfs2-sandbox\\"变为"sandbox\\"
    list_projectName_changePath11 = ["commons-vfs-2.2"]
    #需要把"commons-jcs-core\\src\\main\\java\\org\\apache\\commons\\"变为"src\\java\\org\\apache\\"
    #以及"commons-jcs-sandbox\\yajcache\\src\\main\\java\\org\\apache\\commons\\"变为"sandbox\\yajcache\\src\\org\\apache\\"
    #以及"src\\experimental\\org\\apache\\commons\\"变为"src\\experimental\\org\\apache\\"
    list_projectName_changePath12 = ["commons-jcs-2.0","commons-jcs-2.1","commons-jcs-2.2"]
    #jspwiki-2.9.0需要把"src\\org\\apache\\wiki\\"变为"src\\com\\ecyrd\\jspwiki\\"
    list_projectName_changePath13 = ["jspwiki-2.9.0"]
    #jspwiki-2.10.0需要把"main\\java\\org\\apache\\wiki\\"变为"src\\com\\ecyrd\\jspwiki\\"
    #jspwiki-2.10.0需要把"main\\java\\org\\apache\\catalina\\"变为"src\\org\\apache\\catalina\\"
    list_projectName_changePath14 = ["jspwiki-2.10.0"]
    #需要把"\\knox\\"变为"\\hadoop\\"
    list_projectName_changePath15 = ["knox-1.0.0"]
    #需要把"framework\\cayenne-modeler\\"变为"modeler\\cayenne-modeler\\"
    #需要把"framework\\maven-cayenne-modeler-plugin\\"变为"modeler\\maven-cayenne-modeler-plugin\\"
    list_projectName_changePath16 = ["cayenne-3.0.0"]
    #需要把"src\\java\\fr\\jayasoft\\"变为"src\\java\\org\\apache\\"
    list_projectName_changePath17 = ["ant-ivy-1.4.1"]
    #需要把"src\\main\\"变为"src\\"
    #需要把"\\dbcp2\\"变为"\\dbcp\\"
    list_projectName_changePath18 = ["commons-dbcp-2.0","commons-dbcp-2.1","commons-dbcp-2.2","commons-dbcp-2.3","commons-dbcp-2.4","commons-dbcp-2.5",]
    #需要把"src\\main\\"变为"src\\"
    #需要把"\\jexl2\\"变为"\\jexl\\"
    list_projectName_changePath19 = ["commons-jexl-2.0","commons-jexl-2.1",]
    #需要把"main\\"变为"src\\"
    #需要把"\\jexl3\\"变为"\\jexl\\"
    list_projectName_changePath20 = ["commons-jexl-3.0","commons-jexl-3.1",]
    #需要把"parquet-common\\src\\main\\java\\org\\apache\\"变为"parquet-common\\src\\main\\java\\"
    #需要把"parquet-avro\\src\\main\\java\\org\\apache\\"变为"parquet-avro\\src\\main\\java\\"
    #需要把"parquet-benchmarks\\src\\main\\java\\org\\apache\\"变为"parquet-benchmarks\\src\\main\\java\\"
    #需要把"parquet-encoding\\src\\main\\java\\org\\apache\\"变为"parquet-encoding\\src\\main\\java\\"
    #需要把"parquet-cascading\\src\\main\\java\\org\\apache\\"变为"parquet-cascading\\src\\main\\java\\"
    #需要把"parquet-column\\src\\main\\java\\org\\apache\\"变为"parquet-column\\src\\main\\java\\"
    #需要把"parquet-generator\\src\\main\\java\\org\\apache\\"变为"parquet-generator\\src\\main\\java\\"
    #需要把"parquet-hadoop\\src\\main\\java\\org\\apache\\"变为"parquet-hadoop\\src\\main\\java\\"
    #需要把"parquet-hive\\parquet-hive-storage-handler\\src\\main\\java\\org\\apache\\"变为"parquet-hive\\parquet-hive-storage-handler\\src\\main\\java\\"
    #需要把"parquet-thrift\\src\\main\\java\\org\\apache\\"变为"parquet-thrift\\src\\main\\java\\"
    #需要把"parquet-pig\\src\\main\\java\\org\\apache\\"变为"parquet-pig\\src\\main\\java\\"
    #需要把"parquet-protobuf\\src\\main\\java\\org\\apache\\"变为"parquet-protobuf\\src\\main\\java\\"
    #需要把"parquet-scrooge\\src\\main\\java\\org\\apache\\"变为"parquet-scrooge\\src\\main\\java\\"
    #需要把"parquet-tools\\src\\main\\java\\org\\apache\\"变为"parquet-tools\\src\\main\\java\\"
    list_projectName_changePath21 = ["parquet-mr-1.7.0",]
    
    #因项目版本重复，需在上述变更完后，再变更
    list_projectName_changePath_after1 = [
        "commons-collections-4.0","commons-collections-4.1",#除这几个版本外，之前的版本需要加src
        "commons-configuration-1.8","commons-configuration-1.9","commons-configuration-1.10","commons-configuration-2.0","commons-configuration-2.1","commons-configuration-2.2",#除这几个版本外，之前的版本需要加src
        "commons-lang-2.5","commons-lang-2.6","commons-lang-3.0","commons-lang-3.1","commons-lang-3.2","commons-lang-3.3","commons-lang-3.4","commons-lang-3.5","commons-lang-3.6","commons-lang-3.7",
        "commons-digester-2.1","commons-digester-3.0","commons-digester-3.1","commons-digester-3.2",]
    
    #需要逆统一变更路径
    project_version = projectName + '-' + versionNumber;
    if project_version in list_projectName_changePath1:
        i_crossVersionModule = i_crossVersionModule.replace('src\\','main\\',1);#替换开头处 
    elif project_version in list_projectName_changePath2:
        if project_version == "santuario-java-2.0.0":
            i_crossVersionModule = i_crossVersionModule.replace('src\\','src\\main\\java\\',1);
        if project_version == "santuario-java-2.1.0":
            i_crossVersionModule = i_crossVersionModule.replace('src\\','main\\java\\',1);
    elif project_version in list_projectName_changePath3:
        i_crossVersionModule = i_crossVersionModule.replace('\\collections\\','\\collections4\\',1);
    elif project_version in list_projectName_changePath4:
        i_crossVersionModule = i_crossVersionModule.replace('\\configuration\\','\\configuration2\\',1);
    elif project_version in list_projectName_changePath5:
        i_crossVersionModule = i_crossVersionModule.replace('\\digester\\','\\digester3\\',1);
    elif project_version in list_projectName_changePath6:
        i_crossVersionModule = i_crossVersionModule.replace('\\lang\\','\\lang3\\',1);
    elif project_version in list_projectName_changePath7:
        i_crossVersionModule = i_crossVersionModule.replace('\\math\\','\\math3\\',1);
    elif project_version in list_projectName_changePath8:
        string_added = "core-";
        string_started = "common\\";
        string_started_2 = "cube\\";
        string_started_3 = "dictionary\\";
        string_started_4 = "job\\";
        string_started_5 = "metadata\\";
        string_started_6 = "storage\\";
        startSubscript = len(string_added);
        length_string_started = len(string_started)+startSubscript;
        length_string_started_2 = len(string_started_2)+startSubscript;
        length_string_started_3 = len(string_started_3)+startSubscript;
        length_string_started_4 = len(string_started_4)+startSubscript;
        length_string_started_5 = len(string_started_5)+startSubscript;
        length_string_started_6 = len(string_started_6)+startSubscript;
        if i_crossVersionModule[startSubscript:length_string_started] == string_started \
        or i_crossVersionModule[startSubscript:length_string_started_2] == string_started_2 \
        or i_crossVersionModule[startSubscript:length_string_started_3] == string_started_3 \
        or i_crossVersionModule[startSubscript:length_string_started_4] == string_started_4 \
        or i_crossVersionModule[startSubscript:length_string_started_5] == string_started_5 \
        or i_crossVersionModule[startSubscript:length_string_started_6] == string_started_6:
            i_crossVersionModule = i_crossVersionModule.replace(string_added,'',1);#替换开头处 
        if project_version == "kylin-0.6.1":
            i_crossVersionModule = i_crossVersionModule.replace('\\java\\org\\apache\\kylin\\','\\java\\com\\kylinolap\\',1);
    elif project_version in list_projectName_changePath9:
        i_crossVersionModule = i_crossVersionModule.replace('src\\share\\','main\\java\\',1);
    elif project_version in list_projectName_changePath10:
        i_crossVersionModule = i_crossVersionModule.replace('\\vfs\\','\\vfs2\\',1);
    elif project_version in list_projectName_changePath11:
        i_crossVersionModule = i_crossVersionModule.replace('\\vfs\\','\\vfs2\\',1);
        i_crossVersionModule = i_crossVersionModule.replace('core\\','commons-vfs2\\',1);
        i_crossVersionModule = i_crossVersionModule.replace('sandbox\\','commons-vfs2-sandbox\\',1);
    elif project_version in list_projectName_changePath12:
        i_crossVersionModule = i_crossVersionModule.replace('src\\java\\org\\apache\\','commons-jcs-core\\src\\main\\java\\org\\apache\\commons\\',1);
        i_crossVersionModule = i_crossVersionModule.replace('sandbox\\yajcache\\src\\org\\apache\\','commons-jcs-sandbox\\yajcache\\src\\main\\java\\org\\apache\\commons\\',1);
        i_crossVersionModule = i_crossVersionModule.replace('src\\experimental\\org\\apache\\','src\\experimental\\org\\apache\\commons\\',1);
    elif project_version in list_projectName_changePath13:
        i_crossVersionModule = i_crossVersionModule.replace('src\\com\\ecyrd\\jspwiki\\','src\\org\\apache\\wiki\\',1);
    elif project_version in list_projectName_changePath14:
        i_crossVersionModule = i_crossVersionModule.replace('src\\com\\ecyrd\\jspwiki\\','main\\java\\org\\apache\\wiki\\',1);
        i_crossVersionModule = i_crossVersionModule.replace('src\\org\\apache\\catalina\\','main\\java\\org\\apache\\catalina\\',1);
    elif project_version in list_projectName_changePath15:
        i_crossVersionModule = i_crossVersionModule.replace('\\hadoop\\','\\knox\\',1);
    elif project_version in list_projectName_changePath16:
        i_crossVersionModule = i_crossVersionModule.replace('modeler\\cayenne-modeler\\','framework\\cayenne-modeler\\',1);
        i_crossVersionModule = i_crossVersionModule.replace('modeler\\maven-cayenne-modeler-plugin\\','framework\\maven-cayenne-modeler-plugin\\',1);
    elif project_version in list_projectName_changePath17:
        i_crossVersionModule = i_crossVersionModule.replace('src\\java\\org\\apache\\','src\\java\\fr\\jayasoft\\',1);
    elif project_version in list_projectName_changePath18:
        i_crossVersionModule = i_crossVersionModule.replace('src\\','src\\main\\',1);
        i_crossVersionModule = i_crossVersionModule.replace('\\dbcp\\','\\dbcp2\\',1);
    elif project_version in list_projectName_changePath19:
        i_crossVersionModule = i_crossVersionModule.replace('src\\','src\\main\\',1);
        i_crossVersionModule = i_crossVersionModule.replace('\\jexl\\','\\jexl2\\',1);
    elif project_version in list_projectName_changePath20:
        i_crossVersionModule = i_crossVersionModule.replace('src\\','main\\',1);
        i_crossVersionModule = i_crossVersionModule.replace('\\jexl\\','\\jexl3\\',1);
    elif project_version in list_projectName_changePath21:
        i_crossVersionModule = i_crossVersionModule.replace("parquet-common\\src\\main\\java\\","parquet-common\\src\\main\\java\\org\\apache\\",1);
        i_crossVersionModule = i_crossVersionModule.replace("parquet-avro\\src\\main\\java\\","parquet-avro\\src\\main\\java\\org\\apache\\",1);
        i_crossVersionModule = i_crossVersionModule.replace("parquet-benchmarks\\src\\main\\java\\","parquet-benchmarks\\src\\main\\java\\org\\apache\\",1);
        i_crossVersionModule = i_crossVersionModule.replace("parquet-encoding\\src\\main\\java\\","parquet-encoding\\src\\main\\java\\org\\apache\\",1);
        i_crossVersionModule = i_crossVersionModule.replace("parquet-cascading\\src\\main\\java\\","parquet-cascading\\src\\main\\java\\org\\apache\\",1);
        i_crossVersionModule = i_crossVersionModule.replace("parquet-column\\src\\main\\java\\","parquet-column\\src\\main\\java\\org\\apache\\",1);
        i_crossVersionModule = i_crossVersionModule.replace("parquet-generator\\src\\main\\java\\","parquet-generator\\src\\main\\java\\org\\apache\\",1);
        i_crossVersionModule = i_crossVersionModule.replace("parquet-hadoop\\src\\main\\java\\","parquet-hadoop\\src\\main\\java\\org\\apache\\",1);
        i_crossVersionModule = i_crossVersionModule.replace("parquet-hive\\src\\main\\java\\","parquet-hive\\parquet-hive-storage-handler\\src\\main\\java\\org\\apache\\",1);
        i_crossVersionModule = i_crossVersionModule.replace("parquet-thrift\\src\\main\\java\\","parquet-thrift\\src\\main\\java\\org\\apache\\",1);
        i_crossVersionModule = i_crossVersionModule.replace("parquet-pig\\src\\main\\java\\","parquet-pig\\src\\main\\java\\org\\apache\\",1);
        i_crossVersionModule = i_crossVersionModule.replace("parquet-protobuf\\src\\main\\java\\","parquet-protobuf\\src\\main\\java\\org\\apache\\",1);
        i_crossVersionModule = i_crossVersionModule.replace("parquet-scrooge\\src\\main\\java\\","parquet-scrooge\\src\\main\\java\\org\\apache\\",1);
        i_crossVersionModule = i_crossVersionModule.replace("parquet-tools\\src\\main\\java\\","parquet-tools\\src\\main\\java\\org\\apache\\",1);
    
    #因项目版本重复，需在上述变更完后，再变更
    if project_version in list_projectName_changePath_after1:
        i_crossVersionModule = i_crossVersionModule.replace('src\\','main\\',1);
    
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
    
    #需要去掉特定字符串之前的前缀
    if project_version in list_projectName_removePrefix:
        string_remove = "src\\";
        if i_crossVersionModule[0:4] != string_remove:
            position = i_crossVersionModule.find(string_remove)
            i_crossVersionModule = i_crossVersionModule[position:];
        i_crossVersionModule = i_crossVersionModule.replace(string_remove,'',1);#替换开头处 
    
    if project_version in list_projectSpecificVersion_needPrefix1:
        string_added = "src\\main\\";
        i_crossVersionModule = i_crossVersionModule.replace(string_added,'',1);#替换开头处 
    elif project_version in list_projectSpecificVersion_needPrefix2:
        string_added = "src\\";
        i_crossVersionModule = i_crossVersionModule.replace(string_added,'',1);#替换开头处 
    elif project_version in list_projectSpecificVersion_needPrefix3:
        string_added = "giraph-core\\src\\";
        i_crossVersionModule = i_crossVersionModule.replace(string_added,'',1);#替换开头处 
    elif project_version in list_projectSpecificVersion_needPrefix4:
        if i_crossVersionModule[0:11] != "archiva-cli":
            string_added = "archiva-modules\\";
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

#The module path of some projects in UDB needs to be prefixed with a specific prefix, otherwise there will be no intersection with the instance name in the original defect dataset.
def FUNCTION_HandleSpecialProject_tika(df_low,df_high):
    string_added = "src\\";
    for i_instance in range(len(df_low)):
        cellName = df_low.loc[i_instance,'relName'];
        df_low.loc[i_instance,'relName'] = ''.join([string_added, cellName]);
    
    #需要统一变更路径，因为前后两个相邻版本的路径变了，会导致没有同名实例。
    #"tika-0.1","tika-0.2","tika-0.3"这三个版本，需要根据tika-0.4来加版本头
    ins_low = deque(df_low['relName'].values);
    ins_high = deque(df_high['relName'].values);
    ins_low_copy = copy.copy(ins_low);
    #定义数组下标
    index_low = np.arange(0,len(ins_low));
    
    int_num = 0
    list_deleteIndex = []
    while ins_low_copy:
        x = ins_low_copy.popleft()
        if x in ins_high:
            ins_low.remove(x)
            ins_high.remove(x)
            list_deleteIndex.append(int_num)
        int_num+=1;
    index_low = np.delete(index_low, list_deleteIndex)
    
    ins_low = np.array(ins_low)
    ins_high = np.array(ins_high)
    for i in range(len(ins_low)):
        i_ins_low = ins_low[i]
        index = index_low[i]
        for j in range(len(ins_high)):
            j_ins_high = ins_high[j]
            if i_ins_low in j_ins_high:
                df_low.loc[index,'relName'] = j_ins_high
                ins_high = np.delete(ins_high, j)
                break
    
    return df_low;

def FUNCTION_HandleSpecialProject_label_tika(df_low,df_high):
    #需要统一变更路径，因为前后两个相邻版本的路径变了，会导致没有同名实例。
    #"tika-0.1","tika-0.2","tika-0.3"这三个版本，需要根据tika-0.4来加版本头
    ins_low = deque(df_low['relName'].values);
    ins_high = deque(df_high['relName'].values);
    ins_low_copy = copy.copy(ins_low);
    #定义数组下标
    index_low = np.arange(0,len(ins_low));
    
    int_num = 0
    list_deleteIndex = []
    while ins_low_copy:
        x = ins_low_copy.popleft()
        if x in ins_high:
            ins_low.remove(x)
            ins_high.remove(x)
            list_deleteIndex.append(int_num)
        int_num+=1;
    index_low = np.delete(index_low, list_deleteIndex)
    
    ins_low = np.array(ins_low)
    ins_high = np.array(ins_high)
    for i in range(len(ins_low)):
        i_ins_low = ins_low[i]
        index = index_low[i]
        for j in range(len(ins_high)):
            j_ins_high = ins_high[j]
            if i_ins_low in j_ins_high:
                df_low.loc[index,'relName'] = j_ins_high
                ins_high = np.delete(ins_high, j)
                break
    
    return df_low;

# For the specific datasets used, the file name needs to be normalized, otherwise the corresponding module may not be found in the downloaded project code.
def FUNCTION_HandleSpecialProject(df,projectName,str_versionNumber):
    #需要加"src"前缀的项目列表
    list_projectName_needPrefix1 = ["commons-jcs","commons-beanutils","commons-codec","commons-compress","commons-digester",
                                    "commons-io","commons-net","systemml","wss4j","nutch",]#根据交集结果，统计需要加src的项目
    #需要加"deltaspike"前缀的项目列表
    list_projectName_needPrefix2 = ["deltaspike"];
    
    #需要加"src\\main"前缀的项目版本列表
    list_projectSpecificVersion_needPrefix1 = ["commons-math-1.0","commons-math-1.1","commons-math-1.2"];
    #需要加"src"前缀的项目版本列表
    list_projectSpecificVersion_needPrefix2 = [
        "commons-configuration-1.0","commons-configuration-1.1","commons-configuration-1.2","commons-configuration-1.3","commons-configuration-1.4","commons-configuration-1.5","commons-configuration-1.6","commons-configuration-1.7",
        "commons-collections-1.0","commons-collections-2.0","commons-collections-2.1","commons-collections-3.0","commons-collections-3.1","commons-collections-3.2","commons-collections-3.3",
        "commons-lang-1.0","commons-lang-2.0","commons-lang-2.1","commons-lang-2.2","commons-lang-2.3","commons-lang-2.4",
        "commons-math-2.0","commons-math-2.1","commons-math-2.2","commons-math-3.0","commons-math-3.1","commons-math-3.2","commons-math-3.3","commons-math-3.4","commons-math-3.5","commons-math-3.6",
        "commons-validator-1.0","commons-validator-1.1.0","commons-validator-1.2.0","commons-validator-1.3.0",
        ];
    #需要加"giraph-core\\src\\"前缀的项目版本列表
    list_projectSpecificVersion_needPrefix3 = ["giraph-0.1.0"];
    #需要加"archiva-modules\\"前缀的项目版本列表(除4个以"archiva-cli"开头的特定实例外)
    list_projectSpecificVersion_needPrefix4 = ["archiva-1.0"];
    
    #需要统一变更路径
    list_projectName_changePath1 = ["commons-beanutils-1.9.0",
                                    "commons-bcel-6.0","commons-bcel-6.1","commons-bcel-6.2",#除这三个版本外，之前的版本不需要替换src
                                    "commons-codec-1.6","commons-codec-1.7","commons-codec-1.8","commons-codec-1.9","commons-codec-1.10","commons-codec-1.11",#除这几个版本外，之前的版本需要加src
                                    "commons-io-2.0","commons-io-2.1","commons-io-2.2","commons-io-2.3","commons-io-2.4","commons-io-2.5",
                                    "commons-net-2.0","commons-net-2.1","commons-net-2.2","commons-net-3.0","commons-net-3.1","commons-net-3.2","commons-net-3.3","commons-net-3.4","commons-net-3.5","commons-net-3.6",
                                    ];
    list_projectName_changePath2 = ["santuario-java-2.0.0","santuario-java-2.1.0"];
    list_projectName_changePath3 = ["commons-collections-4.0","commons-collections-4.1"];
    list_projectName_changePath4 = ["commons-configuration-2.0","commons-configuration-2.1","commons-configuration-2.2"];
    list_projectName_changePath5 = ["commons-digester-3.0","commons-digester-3.1","commons-digester-3.2"];
    list_projectName_changePath6 = ["commons-lang-3.0","commons-lang-3.1","commons-lang-3.2","commons-lang-3.3","commons-lang-3.4","commons-lang-3.5","commons-lang-3.6","commons-lang-3.7"];
    list_projectName_changePath7 = ["commons-math-3.0","commons-math-3.1","commons-math-3.2","commons-math-3.3","commons-math-3.4","commons-math-3.5","commons-math-3.6"];
    #需要把"common""cube""dictionary""job""metadata""storage"开头的加上"core-"
    list_projectName_changePath8 = ["kylin-0.6.1","kylin-0.7.1","kylin-1.0.0","kylin-1.1.0","kylin-1.2.0","kylin-1.3.0"];
    #需要把"main\\java\\"变为"src\\share"
    list_projectName_changePath9 = ["commons-validator-1.4.0","commons-validator-1.5.0","commons-validator-1.6.0"]
    #需要把"\\vfs2\\"变为"\\vfs\\"
    list_projectName_changePath10 = ["commons-vfs-2.0","commons-vfs-2.1"]
    #需要把"\\vfs2\\"变为"\\vfs\\"
    #需要把"commons-vfs2\\"变为"core\\"以及"commons-vfs2-sandbox\\"变为"sandbox\\"
    list_projectName_changePath11 = ["commons-vfs-2.2"]
    #需要把"commons-jcs-core\\src\\main\\java\\org\\apache\\commons\\"变为"src\\java\\org\\apache\\"
    #以及"commons-jcs-sandbox\\yajcache\\src\\main\\java\\org\\apache\\commons\\"变为"sandbox\\yajcache\\src\\org\\apache\\"
    #以及"src\\experimental\\org\\apache\\commons\\"变为"src\\experimental\\org\\apache\\"
    list_projectName_changePath12 = ["commons-jcs-2.0","commons-jcs-2.1","commons-jcs-2.2"]
    #jspwiki-2.9.0需要把"src\\org\\apache\\wiki\\"变为"src\\com\\ecyrd\\jspwiki\\"
    list_projectName_changePath13 = ["jspwiki-2.9.0"]
    #jspwiki-2.10.0需要把"main\\java\\org\\apache\\wiki\\"变为"src\\com\\ecyrd\\jspwiki\\"
    #jspwiki-2.10.0需要把"main\\java\\org\\apache\\catalina\\"变为"src\\org\\apache\\catalina\\"
    list_projectName_changePath14 = ["jspwiki-2.10.0"]
    #需要把"\\knox\\"变为"\\hadoop\\"
    list_projectName_changePath15 = ["knox-1.0.0"]
    #需要把"framework\\cayenne-modeler\\"变为"modeler\\cayenne-modeler\\"
    #需要把"framework\\maven-cayenne-modeler-plugin\\"变为"modeler\\maven-cayenne-modeler-plugin\\"
    list_projectName_changePath16 = ["cayenne-3.0.0"]
    #需要把"src\\java\\fr\\jayasoft\\"变为"src\\java\\org\\apache\\"
    list_projectName_changePath17 = ["ant-ivy-1.4.1"]
    #需要把"src\\main\\"变为"src\\"
    #需要把"\\dbcp2\\"变为"\\dbcp\\"
    list_projectName_changePath18 = ["commons-dbcp-2.0","commons-dbcp-2.1","commons-dbcp-2.2","commons-dbcp-2.3","commons-dbcp-2.4","commons-dbcp-2.5",]
    #需要把"src\\main\\"变为"src\\"
    #需要把"\\jexl2\\"变为"\\jexl\\"
    list_projectName_changePath19 = ["commons-jexl-2.0","commons-jexl-2.1",]
    #需要把"main\\"变为"src\\"
    #需要把"\\jexl3\\"变为"\\jexl\\"
    list_projectName_changePath20 = ["commons-jexl-3.0","commons-jexl-3.1",]
    #需要把"parquet-common\\src\\main\\java\\org\\apache\\"变为"parquet-common\\src\\main\\java\\"
    #需要把"parquet-avro\\src\\main\\java\\org\\apache\\"变为"parquet-avro\\src\\main\\java\\"
    #需要把"parquet-benchmarks\\src\\main\\java\\org\\apache\\"变为"parquet-benchmarks\\src\\main\\java\\"
    #需要把"parquet-encoding\\src\\main\\java\\org\\apache\\"变为"parquet-encoding\\src\\main\\java\\"
    #需要把"parquet-cascading\\src\\main\\java\\org\\apache\\"变为"parquet-cascading\\src\\main\\java\\"
    #需要把"parquet-column\\src\\main\\java\\org\\apache\\"变为"parquet-column\\src\\main\\java\\"
    #需要把"parquet-generator\\src\\main\\java\\org\\apache\\"变为"parquet-generator\\src\\main\\java\\"
    #需要把"parquet-hadoop\\src\\main\\java\\org\\apache\\"变为"parquet-hadoop\\src\\main\\java\\"
    #需要把"parquet-hive\\parquet-hive-storage-handler\\src\\main\\java\\org\\apache\\"变为"parquet-hive\\parquet-hive-storage-handler\\src\\main\\java\\"
    #需要把"parquet-thrift\\src\\main\\java\\org\\apache\\"变为"parquet-thrift\\src\\main\\java\\"
    #需要把"parquet-pig\\src\\main\\java\\org\\apache\\"变为"parquet-pig\\src\\main\\java\\"
    #需要把"parquet-protobuf\\src\\main\\java\\org\\apache\\"变为"parquet-protobuf\\src\\main\\java\\"
    #需要把"parquet-scrooge\\src\\main\\java\\org\\apache\\"变为"parquet-scrooge\\src\\main\\java\\"
    #需要把"parquet-tools\\src\\main\\java\\org\\apache\\"变为"parquet-tools\\src\\main\\java\\"
    list_projectName_changePath21 = ["parquet-mr-1.7.0",]
    
    #因项目版本重复，需在上述变更完后，再变更
    list_projectName_changePath_after1 = [
        "commons-collections-4.0","commons-collections-4.1",#除这几个版本外，之前的版本需要加src
        "commons-configuration-1.8","commons-configuration-1.9","commons-configuration-1.10","commons-configuration-2.0","commons-configuration-2.1","commons-configuration-2.2",#除这几个版本外，之前的版本需要加src
        "commons-lang-2.5","commons-lang-2.6","commons-lang-3.0","commons-lang-3.1","commons-lang-3.2","commons-lang-3.3","commons-lang-3.4","commons-lang-3.5","commons-lang-3.6","commons-lang-3.7",
        "commons-digester-2.1","commons-digester-3.0","commons-digester-3.1","commons-digester-3.2",]
    
    #需要统一变更路径，因为前后两个相邻版本的路径变了，会导致没有同名实例。
    versionNumber = str_versionNumber[1:];
    project_version = projectName + '-' + versionNumber;
    if project_version in list_projectName_changePath1:
        df['relName'] = df['relName'].apply(lambda row: row.replace('main\\','src\\'));   
    elif project_version in list_projectName_changePath2:
        if project_version == "santuario-java-2.0.0":
            df['relName'] = df['relName'].apply(lambda row: row.replace('src\\main\\java\\','src\\'));
        if project_version == "santuario-java-2.1.0":
            df['relName'] = df['relName'].apply(lambda row: row.replace('main\\java\\','src\\'));
    elif project_version in list_projectName_changePath3:
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\collections4\\','\\collections\\'));
    elif project_version in list_projectName_changePath4:
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\configuration2\\','\\configuration\\'));
    elif project_version in list_projectName_changePath5:
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\digester3\\','\\digester\\'));
    elif project_version in list_projectName_changePath6:
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\lang3\\','\\lang\\'));
    elif project_version in list_projectName_changePath7:
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\math3\\','\\math\\'));
    elif project_version in list_projectName_changePath8:
        string_added = "core-";
        string_started = "common\\";
        string_started_2 = "cube\\";
        string_started_3 = "dictionary\\";
        string_started_4 = "job\\";
        string_started_5 = "metadata\\";
        string_started_6 = "storage\\";
        length_string_started = len(string_started);
        length_string_started_2 = len(string_started_2);
        length_string_started_3 = len(string_started_3);
        length_string_started_4 = len(string_started_4);
        length_string_started_5 = len(string_started_5);
        length_string_started_6 = len(string_started_6);
        for i_instance in range(len(df)):
            cellName = df.loc[i_instance,'relName'];
            if cellName[0:length_string_started] == string_started \
            or cellName[0:length_string_started_2] == string_started_2 \
            or cellName[0:length_string_started_3] == string_started_3 \
            or cellName[0:length_string_started_4] == string_started_4 \
            or cellName[0:length_string_started_5] == string_started_5 \
            or cellName[0:length_string_started_6] == string_started_6:
                df.loc[i_instance,'relName'] = ''.join([string_added, cellName]);
        if project_version == "kylin-0.6.1":
            df['relName'] = df['relName'].apply(lambda row: row.replace('\\java\\com\\kylinolap\\','\\java\\org\\apache\\kylin\\'));
    elif project_version in list_projectName_changePath9:
        df['relName'] = df['relName'].apply(lambda row: row.replace('main\\java\\','src\\share\\'));
    elif project_version in list_projectName_changePath10:
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\vfs2\\','\\vfs\\'));
    elif project_version in list_projectName_changePath11:
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\vfs2\\','\\vfs\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('commons-vfs2\\','core\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('commons-vfs2-sandbox\\','sandbox\\'));
    elif project_version in list_projectName_changePath12:
        df['relName'] = df['relName'].apply(lambda row: row.replace('commons-jcs-core\\src\\main\\java\\org\\apache\\commons\\','src\\java\\org\\apache\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('commons-jcs-sandbox\\yajcache\\src\\main\\java\\org\\apache\\commons\\','sandbox\\yajcache\\src\\org\\apache\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('src\\experimental\\org\\apache\\commons\\','src\\experimental\\org\\apache\\'));
    elif project_version in list_projectName_changePath13:
        df['relName'] = df['relName'].apply(lambda row: row.replace('src\\org\\apache\\wiki\\','src\\com\\ecyrd\\jspwiki\\'));
    elif project_version in list_projectName_changePath14:
        df['relName'] = df['relName'].apply(lambda row: row.replace('main\\java\\org\\apache\\wiki\\','src\\com\\ecyrd\\jspwiki\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('main\\java\\org\\apache\\catalina\\','src\\org\\apache\\catalina\\'));
    elif project_version in list_projectName_changePath15:
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\knox\\','\\hadoop\\'));
    elif project_version in list_projectName_changePath16:
        df['relName'] = df['relName'].apply(lambda row: row.replace('framework\\cayenne-modeler\\','modeler\\cayenne-modeler\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('framework\\maven-cayenne-modeler-plugin\\','modeler\\maven-cayenne-modeler-plugin\\'));
    elif project_version in list_projectName_changePath17:
        df['relName'] = df['relName'].apply(lambda row: row.replace('src\\java\\fr\\jayasoft\\','src\\java\\org\\apache\\'));
    elif project_version in list_projectName_changePath18:
        df['relName'] = df['relName'].apply(lambda row: row.replace('src\\main\\','src\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\dbcp2\\','\\dbcp\\'));
    elif project_version in list_projectName_changePath19:
        df['relName'] = df['relName'].apply(lambda row: row.replace('src\\main\\','src\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\jexl2\\','\\jexl\\'));
    elif project_version in list_projectName_changePath20:
        df['relName'] = df['relName'].apply(lambda row: row.replace('main\\','src\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\jexl3\\','\\jexl\\'));
    elif project_version in list_projectName_changePath21:
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-common\\src\\main\\java\\org\\apache\\","parquet-common\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-avro\\src\\main\\java\\org\\apache\\","parquet-avro\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-benchmarks\\src\\main\\java\\org\\apache\\","parquet-benchmarks\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-encoding\\src\\main\\java\\org\\apache\\","parquet-encoding\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-cascading\\src\\main\\java\\org\\apache\\","parquet-cascading\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-column\\src\\main\\java\\org\\apache\\","parquet-column\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-generator\\src\\main\\java\\org\\apache\\","parquet-generator\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-hadoop\\src\\main\\java\\org\\apache\\","parquet-hadoop\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-hive\\parquet-hive-storage-handler\\src\\main\\java\\org\\apache\\","parquet-hive\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-thrift\\src\\main\\java\\org\\apache\\","parquet-thrift\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-pig\\src\\main\\java\\org\\apache\\","parquet-pig\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-protobuf\\src\\main\\java\\org\\apache\\","parquet-protobuf\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-scrooge\\src\\main\\java\\org\\apache\\","parquet-scrooge\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-tools\\src\\main\\java\\org\\apache\\","parquet-tools\\src\\main\\java\\"));
    
    #因项目版本重复，需在上述变更完后，再变更
    if project_version in list_projectName_changePath_after1:
        df['relName'] = df['relName'].apply(lambda row: row.replace('main\\','src\\'));
    
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
    elif project_version in list_projectSpecificVersion_needPrefix3:
        string_added = "giraph-core\\src\\";
        for i_instance in range(len(df)):
            cellName = df.loc[i_instance,'relName'];
            df.loc[i_instance,'relName'] = ''.join([string_added, cellName]);
    elif project_version in list_projectSpecificVersion_needPrefix4:
        string_added = "archiva-modules\\";
        for i_instance in range(len(df)):
            cellName = df.loc[i_instance,'relName'];
            if cellName[0:11] != "archiva-cli":
                df.loc[i_instance,'relName'] = ''.join([string_added, cellName]);
    
    return df;

#The path of specific projects in the original defect dataset needs to be changed, otherwise there will be no intersection with the module in UDB file.
def FUNCTION_HandleSpecialProject_label(df,projectName,str_versionNumber):
    #需要加"giraph-core\\"前缀的项目版本列表
    list_projectSpecificVersion_needPrefix3 = ["giraph-0.1.0"];
    #需要加"archiva-modules\\"前缀的项目版本列表(除特定4个实例外)
    list_projectSpecificVersion_needPrefix4 = ["archiva-1.0"];
    
    #需要把"src\\main\\"变为"src\\"
    list_projectName_changePath1 = [
                                    "commons-bcel-6.0","commons-bcel-6.1","commons-bcel-6.2",
                                    "commons-codec-1.6","commons-codec-1.7","commons-codec-1.8","commons-codec-1.9","commons-codec-1.10","commons-codec-1.11",
                                    "commons-collections-4.0","commons-collections-4.1",
                                    "commons-configuration-1.8","commons-configuration-1.9","commons-configuration-1.10","commons-configuration-2.0","commons-configuration-2.1","commons-configuration-2.2",
                                    "commons-digester-2.1","commons-digester-3.0","commons-digester-3.1","commons-digester-3.2",
                                    "commons-io-2.0","commons-io-2.1","commons-io-2.2","commons-io-2.3","commons-io-2.4","commons-io-2.5",
                                    "commons-lang-2.5","commons-lang-2.6","commons-lang-3.0","commons-lang-3.1","commons-lang-3.2","commons-lang-3.3","commons-lang-3.4","commons-lang-3.5","commons-lang-3.6","commons-lang-3.7",
                                    "commons-net-2.0","commons-net-2.1","commons-net-2.2","commons-net-3.0","commons-net-3.1","commons-net-3.2","commons-net-3.3","commons-net-3.4","commons-net-3.5","commons-net-3.6",
                                    ];
    #需要把"src\\main\\java"变为"src\\"
    list_projectName_changePath2 = ["santuario-java-2.0.0","santuario-java-2.1.0"]
    #需要把"common""cube""dictionary""job""metadata""storage"开头的加上"core-"
    list_projectName_changePath8 = ["kylin-0.6.1","kylin-0.7.1","kylin-1.0.0","kylin-1.1.0","kylin-1.2.0","kylin-1.3.0"];
    #需要把"src\\main\\java"变为"src\\share"
    list_projectName_changePath9 = ["commons-validator-1.4.0","commons-validator-1.5.0","commons-validator-1.6.0"];
    #需要把"\\vfs2\\"变为"\\vfs\\"
    list_projectName_changePath10 = ["commons-vfs-2.0","commons-vfs-2.1"]
    #需要把"\\vfs2\\"变为"\\vfs\\"
    #需要把"commons-vfs2\\"变为"core\\"以及"commons-vfs2-sandbox\\"变为"sandbox\\"
    list_projectName_changePath11 = ["commons-vfs-2.2"]
    #需要把"commons-jcs-core\\src\\main\\java\\org\\apache\\commons\\"变为"src\\java\\org\\apache\\"
    #以及"commons-jcs-sandbox\\yajcache\\src\\main\\java\\org\\apache\\commons\\"变为"sandbox\\yajcache\\src\\org\\apache\\"
    #以及"src\\experimental\\org\\apache\\commons\\"变为"src\\experimental\\org\\apache\\"
    list_projectName_changePath12 = ["commons-jcs-2.0","commons-jcs-2.1","commons-jcs-2.2"]
    #jspwiki-2.9.0需要把"src\\org\\apache\\wiki\\"变为"src\\com\\ecyrd\\jspwiki\\"
    list_projectName_changePath13 = ["jspwiki-2.9.0"]
    #jspwiki-2.10.0需要把"src\\main\\java\\org\\apache\\wiki\\"变为"src\\com\\ecyrd\\jspwiki\\"
    #jspwiki-2.10.0需要把"src\\main\\java\\org\\apache\\catalina\\"变为"src\\org\\apache\\catalina\\"
    list_projectName_changePath14 = ["jspwiki-2.10.0"]
    #需要把"\\knox\\"变为"\\hadoop\\"
    list_projectName_changePath15 = ["knox-1.0.0"]
    #需要把"framework\\cayenne-modeler\\"变为"modeler\\cayenne-modeler\\"
    #需要把"framework\\maven-cayenne-modeler-plugin\\"变为"modeler\\maven-cayenne-modeler-plugin\\"
    list_projectName_changePath16 = ["cayenne-3.0.0"]
    #需要把"src\\java\\fr\\jayasoft\\"变为"src\\java\\org\\apache\\"
    list_projectName_changePath17 = ["ant-ivy-1.4.1"]
    #需要把"src\\main\\"变为"src\\"
    #需要把"\\dbcp2\\"变为"\\dbcp\\"
    list_projectName_changePath18 = ["commons-dbcp-2.0","commons-dbcp-2.1","commons-dbcp-2.2","commons-dbcp-2.3","commons-dbcp-2.4","commons-dbcp-2.5",]
    #需要把"src\\main\\"变为"src\\"
    #需要把"\\jexl2\\"变为"\\jexl\\"
    list_projectName_changePath19 = ["commons-jexl-2.0","commons-jexl-2.1",]
    #需要把"src\\main\\"变为"src\\"
    #需要把"\\jexl2\\"变为"\\jexl\\"
    list_projectName_changePath20 = ["commons-jexl-3.0","commons-jexl-3.1",]
    #需要把"parquet-common\\src\\main\\java\\org\\apache\\"变为"parquet-common\\src\\main\\java\\"
    #需要把"parquet-avro\\src\\main\\java\\org\\apache\\"变为"parquet-avro\\src\\main\\java\\"
    #需要把"parquet-benchmarks\\src\\main\\java\\org\\apache\\"变为"parquet-benchmarks\\src\\main\\java\\"
    #需要把"parquet-encoding\\src\\main\\java\\org\\apache\\"变为"parquet-encoding\\src\\main\\java\\"
    #需要把"parquet-cascading\\src\\main\\java\\org\\apache\\"变为"parquet-cascading\\src\\main\\java\\"
    #需要把"parquet-column\\src\\main\\java\\org\\apache\\"变为"parquet-column\\src\\main\\java\\"
    #需要把"parquet-generator\\src\\main\\java\\org\\apache\\"变为"parquet-generator\\src\\main\\java\\"
    #需要把"parquet-hadoop\\src\\main\\java\\org\\apache\\"变为"parquet-hadoop\\src\\main\\java\\"
    #需要把"parquet-hive\\parquet-hive-storage-handler\\src\\main\\java\\org\\apache\\"变为"parquet-hive\\parquet-hive-storage-handler\\src\\main\\java\\"
    #需要把"parquet-thrift\\src\\main\\java\\org\\apache\\"变为"parquet-thrift\\src\\main\\java\\"
    #需要把"parquet-pig\\src\\main\\java\\org\\apache\\"变为"parquet-pig\\src\\main\\java\\"
    #需要把"parquet-protobuf\\src\\main\\java\\org\\apache\\"变为"parquet-protobuf\\src\\main\\java\\"
    #需要把"parquet-scrooge\\src\\main\\java\\org\\apache\\"变为"parquet-scrooge\\src\\main\\java\\"
    #需要把"parquet-tools\\src\\main\\java\\org\\apache\\"变为"parquet-tools\\src\\main\\java\\"
    list_projectName_changePath21 = ["parquet-mr-1.7.0",]
    
    #需要统一变更路径，因为前后两个相邻版本的路径变了，会导致没有同名实例。
    versionNumber = str_versionNumber[1:];
    project_version = projectName + '-' + versionNumber;
    if project_version in list_projectName_changePath1:
        df['relName'] = df['relName'].apply(lambda row: row.replace('src\\main\\','src\\'));
    elif project_version in list_projectName_changePath2:
        df['relName'] = df['relName'].apply(lambda row: row.replace('src\\main\\java\\','src\\'));
    elif project_version in list_projectName_changePath8:#需要把"common""cube""dictionary""job""metadata""storage"开头的加上"core-"
        string_added = "core-";
        string_started = "common\\";
        string_started_2 = "cube\\";
        string_started_3 = "dictionary\\";
        string_started_4 = "job\\";
        string_started_5 = "metadata\\";
        string_started_6 = "storage\\";
        length_string_started = len(string_started);
        length_string_started_2 = len(string_started_2);
        length_string_started_3 = len(string_started_3);
        length_string_started_4 = len(string_started_4);
        length_string_started_5 = len(string_started_5);
        length_string_started_6 = len(string_started_6);
        for i_instance in range(len(df)):
            cellName = df.loc[i_instance,'relName'];
            if cellName[0:length_string_started] == string_started \
            or cellName[0:length_string_started_2] == string_started_2 \
            or cellName[0:length_string_started_3] == string_started_3 \
            or cellName[0:length_string_started_4] == string_started_4 \
            or cellName[0:length_string_started_5] == string_started_5 \
            or cellName[0:length_string_started_6] == string_started_6:
                df.loc[i_instance,'relName'] = ''.join([string_added, cellName]);
        if project_version == "kylin-0.6.1":
            df['relName'] = df['relName'].apply(lambda row: row.replace('\\java\\com\\kylinolap\\','\\java\\org\\apache\\kylin\\'));
    elif project_version in list_projectName_changePath9:
        df['relName'] = df['relName'].apply(lambda row: row.replace('src\\main\\java\\','src\\share\\'));
    elif project_version in list_projectName_changePath10:
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\vfs2\\','\\vfs\\'));
    elif project_version in list_projectName_changePath11:
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\vfs2\\','\\vfs\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('commons-vfs2\\','core\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('commons-vfs2-sandbox\\','sandbox\\'));
    elif project_version in list_projectName_changePath12:
        df['relName'] = df['relName'].apply(lambda row: row.replace('commons-jcs-core\\src\\main\\java\\org\\apache\\commons\\','src\\java\\org\\apache\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('commons-jcs-sandbox\\yajcache\\src\\main\\java\\org\\apache\\commons\\','sandbox\\yajcache\\src\\org\\apache\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('src\\experimental\\org\\apache\\commons\\','src\\experimental\\org\\apache\\'));
    elif project_version in list_projectName_changePath13:
        df['relName'] = df['relName'].apply(lambda row: row.replace('src\\org\\apache\\wiki\\','src\\com\\ecyrd\\jspwiki\\'));
    elif project_version in list_projectName_changePath14:
        df['relName'] = df['relName'].apply(lambda row: row.replace('src\\main\\java\\org\\apache\\wiki\\','src\\com\\ecyrd\\jspwiki\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('src\\main\\java\\org\\apache\\catalina\\','src\\org\\apache\\catalina\\'));
    elif project_version in list_projectName_changePath15:
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\knox\\','\\hadoop\\'));
    elif project_version in list_projectName_changePath16:
        df['relName'] = df['relName'].apply(lambda row: row.replace('framework\\cayenne-modeler\\','modeler\\cayenne-modeler\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('framework\\maven-cayenne-modeler-plugin\\','modeler\\maven-cayenne-modeler-plugin\\'));
    elif project_version in list_projectName_changePath17:
        df['relName'] = df['relName'].apply(lambda row: row.replace('src\\java\\fr\\jayasoft\\','src\\java\\org\\apache\\'));
    elif project_version in list_projectName_changePath18:
        df['relName'] = df['relName'].apply(lambda row: row.replace('src\\main\\','src\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\dbcp2\\','\\dbcp\\'));
    elif project_version in list_projectName_changePath19:
        df['relName'] = df['relName'].apply(lambda row: row.replace('src\\main\\','src\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\jexl2\\','\\jexl\\'));
    elif project_version in list_projectName_changePath20:
        df['relName'] = df['relName'].apply(lambda row: row.replace('src\\main\\','src\\'));
        df['relName'] = df['relName'].apply(lambda row: row.replace('\\jexl2\\','\\jexl\\'));
    elif project_version in list_projectName_changePath21:
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-common\\src\\main\\java\\org\\apache\\","parquet-common\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-avro\\src\\main\\java\\org\\apache\\","parquet-avro\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-benchmarks\\src\\main\\java\\org\\apache\\","parquet-benchmarks\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-encoding\\src\\main\\java\\org\\apache\\","parquet-encoding\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-cascading\\src\\main\\java\\org\\apache\\","parquet-cascading\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-column\\src\\main\\java\\org\\apache\\","parquet-column\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-generator\\src\\main\\java\\org\\apache\\","parquet-generator\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-hadoop\\src\\main\\java\\org\\apache\\","parquet-hadoop\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-hive\\parquet-hive-storage-handler\\src\\main\\java\\org\\apache\\","parquet-hive\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-thrift\\src\\main\\java\\org\\apache\\","parquet-thrift\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-pig\\src\\main\\java\\org\\apache\\","parquet-pig\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-protobuf\\src\\main\\java\\org\\apache\\","parquet-protobuf\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-scrooge\\src\\main\\java\\org\\apache\\","parquet-scrooge\\src\\main\\java\\"));
        df['relName'] = df['relName'].apply(lambda row: row.replace("parquet-tools\\src\\main\\java\\org\\apache\\","parquet-tools\\src\\main\\java\\"));
    
    #需要增加前缀
    if project_version in list_projectSpecificVersion_needPrefix3:
        string_added = "giraph-core\\";
        for i_instance in range(len(df)):
            cellName = df.loc[i_instance,'relName'];
            df.loc[i_instance,'relName'] = ''.join([string_added, cellName]);
    elif project_version in list_projectSpecificVersion_needPrefix4:
        string_added = "archiva-modules\\";
        for i_instance in range(len(df)):
            cellName = df.loc[i_instance,'relName'];
            temp_1 = cellName[0:11]
            if temp_1 != "archiva-cli":
                df.loc[i_instance,'relName'] = ''.join([string_added, cellName]);
    
#     #需要加"src\\main"前缀的项目版本列表
#     list_projectSpecificVersion_needPrefix1 = ["commons-math-1.0","commons-math-1.1","commons-math-1.2"];
#     #需要统一变更路径，因为前后两个相邻版本的路径变了，会导致没有同名实例。
#     versionNumber = str_versionNumber[1:];
#     project_version = projectName + '-' + versionNumber;
#     if project_version in list_projectSpecificVersion_needPrefix1:
#         df['relName'] = df['relName'].apply(lambda row: row.replace('src\\','src\\main\\'));
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
    if dataset_style == "Metrics-Repo-2010":#原始数据集两个name列,'className'列没有分隔符，是'.'号
        df_file_original.rename(columns={'name.1':'className'}, inplace=True);
        df_file_original.drop(['name','version'], axis=1, inplace=True);#只有Metrics-Repo-2010自带version列，先删除，之后统一加上带字母v的version列
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
    elif dataset_style in ["IND-JLMIV+R-2020","6M-SZZ-2020"]:
        df_file_original['relName'] = df_file_original['relName'].apply(lambda row: FUNCTION_separatorSubstitution(row));
    #===To calculate the bug density, the ranking indicators need to use the bug density===#
    df_file_original['bugDensity'] = df_file_original['bug']/df_file_original['loc'];
    df_file_original.fillna(0, inplace=True);
    # change the number of bug to the label (0 or 1)
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
    # The following procedure only serves the Metrics-Repo-2010 dataset
    df_de_duplication_copy = df_de_duplication.copy()
     
    #===Determine the relname of the inner class in the dataframe===#
    # group by relName
    series_group = df_oneVersion.groupby(['relName'])['relName'].count();#Exception: Data must be 1-dimensional
    dict_series_group = {'relName':series_group.index,'numbers':series_group.values};
    df_group = pd.DataFrame(dict_series_group);
    #===end===#
     
    #===Select the correct 'classname' for each 'relname'===#
    list_includeInnerClassesRelName = df_group[df_group['numbers'] != 1]['relName'].tolist();
    for i_innerRelName in list_includeInnerClassesRelName:
        list_innerClassName = df_oneVersion[df_oneVersion['relName'] == i_innerRelName]['className'].tolist();
        index_start = i_innerRelName.rfind('\\')+1;
        index_end = i_innerRelName.rfind('.');
        mainClassName = i_innerRelName[index_start:index_end];
         
        for j_className in list_innerClassName:
            index_start = j_className.rfind('.')+1;
            one_innerClassName = j_className[index_start:];
            if one_innerClassName == mainClassName:
                index_rel = df_de_duplication[df_de_duplication['relName'] == i_innerRelName].index.tolist()[0];
                df_de_duplication_copy.loc[index_rel,'className'] = j_className;
                break;
    #===end===#
    df_de_duplication_copy.reset_index(drop=True,inplace=True);
    return df_de_duplication_copy;
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
#     dataset_style = "JIRA-RA-2019";
#     dataset_style = "JIRA-HA-2019";
#     dataset_style = "ECLIPSE-2007";
#     dataset_style = "MA-SZZ-2020";
#     dataset_style = "IND-JLMIV+R-2020";
    # project list
    projectName_list = ['ant','camel','forrest','jedit','log4j','lucene','pbeans','poi','synapse','velocity','xalan','xerces'];
#     projectName_list = ['activemq','camel','derby','groovy','hbase','hive','jruby','lucene','wicket'];
#     projectName_list = ['eclipse'];
#     projectName_list = ["zeppelin","shiro","maven","flume","mahout"];
#     projectName_list = ["ant-ivy","archiva","calcite","cayenne","commons-bcel","commons-beanutils","commons-codec","commons-collections",
#                         "commons-compress","commons-configuration","commons-dbcp","commons-digester","commons-io","commons-jcs","commons-jexl",
#                         "commons-lang","commons-math","commons-net","commons-scxml","commons-validator","commons-vfs","deltaspike","eagle",
#                         "giraph","gora","jspwiki","knox","kylin","lens","mahout","manifoldcf","nutch","opennlp","parquet-mr","santuario-java","systemml","tika","wss4j",];
    
    
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
                #特殊的tika的处理
                if i_projectName == "tika" and str_versionNumber in ['v0.1','v0.2','v0.3']:
                    i_fileUdb_benchmark = "tika-0.4.udb";
                    i_fileLabels_benchmark = "tika-0.4.csv";
                    str_versionNumber_benchmark = FUNCTION_getVersionNumber(i_fileUdb_benchmark);
                    filePath_currentVersion_benchmark = folderName_project + i_fileUdb_benchmark;
                    list_information_allRows_currentVersion = FUNCTION_readFileList(filePath_currentVersion_benchmark,str_versionNumber_benchmark);
                    df_oneVersion_removeRedundant_4 = FUNCTION_removeRedundantInnerClasses(list_information_allRows_currentVersion);
                    fileLabelsPath_currentVersion_benchmark = folderName_project_labels + i_fileLabels_benchmark;
                    df_labels_currentVersion_4 = FUNCTION_readLabelsDatasets(fileLabelsPath_currentVersion_benchmark,dataset_style);
                    SV_i_df = FUNCTION_HandleSpecialProject_tika(SV_i_df,df_oneVersion_removeRedundant_4);
                    DV_i_df = FUNCTION_HandleSpecialProject_label_tika(DV_i_df,df_labels_currentVersion_4);
                else:
                    SV_i_df = FUNCTION_HandleSpecialProject(SV_i_df,i_projectName,str_versionNumber);
                    DV_i_df = FUNCTION_HandleSpecialProject_label(DV_i_df,i_projectName,str_versionNumber);
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
    
    
    
    
    
    
    
    
    
    
    
    
    