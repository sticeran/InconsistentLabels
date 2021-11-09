'''

'''

import os
import re
import pandas as pd
from collections import OrderedDict

#获得每个引入buggy line的提交号和引入时间，修复提交号和修复时间，问题报告的创建时间。并过滤引入时间大于创建时间的引入提交。
if __name__ == "__main__":
    projectName_list = ["zeppelin","shiro","maven","flume","mahout"];
#     projectName_list = ["shiro"];#调试用
    
#     string = "(123)"
#     string = "(123(123)123)"
#     string = "(Karuppayya 2015-08-09 11:38:47 +0530 419)"
#     string = "123(Kevin( SangWoo) 1ambda 2014-11-19 12:33:03 +0900 432)123"
#     a1 = [m.start() for m in re.finditer('\(', string)];
#     a2 = [m.start() for m in re.finditer('\)', string)];
#     aaa = string[a1[0]:a2[len(a2)-1]+1]
#     a3 = aaa.index('-')
#     aaa = aaa[a3-4:]
#     aaa = re.findall('\([^()]*\)', string)
#     bbb = re.findall(r'[0-9].*$', aaa, re.S)[0];
#     bbb = re.sub('\([^()]*\)','',string, re.S)
    
    path_common_bugid_fixingsha = 'D:/workspace/mixed-workspace/mySZZ/matching_bugid_fixingsha';
    path_common_blame = 'D:/workspace/mixed-workspace/mySZZ/git_blame_l_from_buggyFileAndLineNum';
    path_common_saved = 'D:/workspace/mixed-workspace/mySZZ/bugIntroducingTime_and_bugFixingtime';
    
    wcsv_list_bugFilename = [];
    wcsv_list_bugIntroducingTime = [];
    wcsv_list_bugFixingTime = [];
    wcsv_list_bugIntroducingCommitsSha = [];
    wcsv_list_bugFixingCommitsSha = [];
    wcsv_list_buggyLine = [];
    wcsv_list_issueReportsCreatedDate = [];
    
    for project in projectName_list:
        print(project+" begin")
        path_bugid_fixingsha = path_common_bugid_fixingsha+'/%s_bug_commit_all.txt'%project;
        allLine_fixingsha = open(path_bugid_fixingsha,'r').readlines();#所有潜在的修复bug的commits号和修复时间，以及问题报告的创建时间
        project_dir = path_common_blame+'/%s'%project;
        fileNames_bugIntroducingCommits = os.listdir(project_dir);#所有包含有效修改行的修复bug的commits对应的有效修改行信息的文件名
        for str_i_filename in fileNames_bugIntroducingCommits:
            print(str_i_filename)
            tempList = str_i_filename.split('_');
            bugFixingCommits_sha = tempList[1];#修复bug的提交号
            path_i_filename = project_dir + '/%s'%str_i_filename;
            allLine_filename = open(path_i_filename,'r',encoding='UTF-16').readlines();#一个修复bug的commit对应的所有buggy line对应的潜在的引入bug的commits号和引入时间
            for oneLine_filename in allLine_filename:#一行buggy line对应的潜在的引入bug的commits号和引入时间
                if oneLine_filename == "\n":
                    continue;
                list_oneLine = oneLine_filename.split(' ');
                bugIntroducingCommits_sha = list_oneLine[0];#引入bug的提交号
                bugIntroducingCommits_filename = list_oneLine[1];#引入bug的文件名
                index_buggyLine = oneLine_filename.index(')');
                buggyLine = oneLine_filename[index_buggyLine+2:];#buggy line,+2是为了去掉)和一个间隔空格
                buggyLine = re.sub("(\r|\n)", '', buggyLine)#去掉末尾的换行符
                #===过滤引入时间大于创建时间的引入提交===#
#                 str_round_brackets = re.findall(r'[(](.*?)[)]', oneLine_filename, re.S)[0];#最小匹配,取圆括号里面的时间信息#有些人名里带小括号，需要先过掉掉
                list_index_left = [m.start() for m in re.finditer('\(', oneLine_filename)];#需要第一个(的下标
                list_index_right = [m.start() for m in re.finditer('\)', oneLine_filename)];#需要最后一个)的下标
                str_round_brackets = oneLine_filename[list_index_left[0]:list_index_right[len(list_index_right)-1]+1];#取圆括号里面的包含时间在内的信息
                index_connector = str_round_brackets.index('-');
                str_round_brackets = str_round_brackets[index_connector-4:];#去掉圆括号里面的作者信息
                temp_list = str_round_brackets.split(' ');
                time_bugIntroduing = temp_list[0:2];#引入bug的时间
                #获取修复bug的commits的修复bug时间，以及问题报告的创建时间
                for i_onelien_fixingsha in allLine_fixingsha:
                    if i_onelien_fixingsha.find(bugFixingCommits_sha)!=-1:
                        i_onelien_fixingsha = i_onelien_fixingsha.replace('\n','')
                        tempList = i_onelien_fixingsha.split(' ');
                        time_createdDate = tempList[2:4];#问题报告创建时间
                        time_bugFixing = tempList[4:6];#修复bug的时间
                        break;
                str_time_bugIntroduing = ' '.join(time_bugIntroduing)
                str_time_createdDate = ' '.join(time_createdDate)
                str_time_bugFixing = ' '.join(time_bugFixing)
                if str_time_bugIntroduing <= str_time_createdDate:
                    wcsv_list_bugFilename.append(bugIntroducingCommits_filename)
                    wcsv_list_bugIntroducingTime.append(str_time_bugIntroduing)
                    wcsv_list_bugFixingTime.append(str_time_bugFixing)
                    wcsv_list_bugIntroducingCommitsSha.append(bugIntroducingCommits_sha)
                    wcsv_list_bugFixingCommitsSha.append(bugFixingCommits_sha)
                    wcsv_list_buggyLine.append(buggyLine)
                    wcsv_list_issueReportsCreatedDate.append(str_time_createdDate)
                #===end===#
        wcsv_columns = OrderedDict([('bugFilename',wcsv_list_bugFilename),
                        ('bugIntroducingTime',wcsv_list_bugIntroducingTime),
                        ('bugFixingTime',wcsv_list_bugFixingTime),
                        ('bugIntroducingCommitsSha',wcsv_list_bugIntroducingCommitsSha),
                        ('bugFixingCommitsSha',wcsv_list_bugFixingCommitsSha),
                        ('buggyLine',wcsv_list_buggyLine),
                        ('issueReportsCreatedDate',wcsv_list_issueReportsCreatedDate)]);
        df_saved = pd.DataFrame.from_dict(wcsv_columns);
        df_saved.to_csv(path_common_saved + '/%s/buggyLinesIntervals.csv'%project,index=False);#不保存行索引
        print(project+" finish")






