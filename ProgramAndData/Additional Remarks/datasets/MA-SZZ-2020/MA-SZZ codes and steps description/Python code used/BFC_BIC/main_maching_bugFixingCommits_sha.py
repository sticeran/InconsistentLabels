# -*- coding: utf-8 -*-
#文件原名maching_id_sha

import pandas as pd
import csv
import copy
import os 
import re
import datetime

#显示所有列
pd.set_option('display.max_columns', None)
#显示所有行
pd.set_option('display.max_rows', None)
pd.set_option('max_colwidth',200);#设置value的显示长度为200，默认为50

#获取修复bug的提交号（这一步不用获得修复时间，因为很多修复提交不是对文件bug的修复）
#存bug报告时间和修复bug时间，后面步骤就不用那么乱了
if __name__ == "__main__":
    
#     reline = [1,2,3]
#     i = 0;
#     len = len(reline)
#     while i < len:
#         str_oneLine = reline[i]
#         if str_oneLine == 1:
#             reline.remove(str_oneLine)
#             i-=1;
#             len-=1;
#         i+=1;
    
#     for i in range(2):
#         for str_oneLine in reline:#这个for循环有问题
#             if str_oneLine == 1:
#                 reline.remove(str_oneLine)
#                 break;

    direct = {'zeppelin':'ZEPPELIN-',
              'shiro':'SHIRO-',
              'maven':'MNG-',
              'flume':'FLUME-',
              'mahout':'MAHOUT-',
            }
#     direct = {
#               'mahout':'MAHOUT-',
#             }#调试用
    
    path_common = "D:/workspace/mixed-workspace/mySZZ";
    
    for project in direct:
        
        bug_name = direct[project]
        
#         if os.path.exists('%s/matching_bugid_fixingsha/%s_bug_commit_all.txt'%(path_common,project)):
#             continue
        
        project_dir = '%s/issue_reports_from_JIRA/issue_reports/%s'%(path_common,project)
        
        #---获取bugID和问题报告的创建时间---#
        df_issueReports_all = pd.DataFrame();
        fileNames_issueReports = os.listdir(project_dir);
        for str_i_filename in fileNames_issueReports:
            filePath_issueReports = project_dir + "/" + str_i_filename;#文件路径
            df_issueReports = pd.read_csv(filePath_issueReports);
            df_issueReports_all = df_issueReports_all.append(df_issueReports);
        df_issueReports_all = df_issueReports_all[(df_issueReports_all['type'] == 'Bug') & (df_issueReports_all['resolution'] == 'Fixed')];
        df_issueReports_all = df_issueReports_all[(df_issueReports_all['status'] == 'Closed') | (df_issueReports_all['status'] == 'Resolved')];
        list_bugID = df_issueReports_all['issueKey'].tolist();
        list_createdDate = df_issueReports_all['createdDateEpoch'].tolist();#list_createdDate需要按标准日期做进一步转化
        list_createdDate = [str(datetime.datetime.strptime(i_date,'%Y/%m/%d %H:%M')) for i_date in list_createdDate];
        dict_bug_date = dict(zip(list_bugID,list_createdDate));#创建字典
#         df_bugID = pd.read_csv(filePath_bugID, header=None);
#         list_bugID = df_bugID[0].tolist();
        #---end---#
        
        #---获取git log---#
        filePath_gitLog = '%s/git_log_from_GitRepository/%s/git_log.csv'%(path_common,project)
        csvfile = open(filePath_gitLog, 'r',encoding='UTF-16')
        reader = csv.reader(csvfile)
        #---end---#
        
        seperator = "#sep#";
        # read csv and get the summary
        br = 0
        reline = []
        #commit = []
        for line in reader:
            try:
                for ele in line:
                    ele = ele.lower()
                    if ele.find(seperator)!=-1:
                        br+=1
                        if ele.find(seperator)!=-1 and ele.find("%s"%(bug_name.lower()))!=-1:
                            reline.append(ele)
                        elif ele.find(seperator)!=-1 and re.findall(r"(.*)[ _-]fix[ _-](.*)|fix[ _-](.*)",ele,re.I) and re.findall(r"\d{1,5}",ele):
                            reline.append(ele)
            except:
                print ('NULL')
        commit_sum = br
        csvfile.close()
        
        #match bug id and commit through summary
        vbugid = []
        vcommit = []
        vcreatedDate = []
        vfixingDate = []
        nobugid = []
    
        rename = copy.deepcopy(list_bugID)
    
        for str_oneLine in reline:
#             print(str_oneLine)
            items = str_oneLine.split(seperator);
            summary = items[3];
            fixingDate = items[2];
            index_firstSpace = fixingDate.find(' ');#第一次出现的位置
            index_secondSpace = fixingDate.find(' ',index_firstSpace+1);#第二次出现的位置
            fixingDate = fixingDate[0:index_secondSpace];

            for bugNameID in rename:
                bugNameID_ID = bugNameID.split('-',1)[1];#only bugId
                if summary.find('%s'%bugNameID.lower())!=-1:
                    if(re.findall(r"%s(.*?)\D"%bug_name.lower(), summary)):
                        summary_bugid = re.findall(r"%s(.*?)\D"%bug_name.lower(), summary)
                    else:
                        summary_bugid = re.findall(r"%s(.*?)$"%bug_name.lower(), summary)
                    tmp = ('%s'%bug_name)+summary_bugid[0]
                    if bugNameID == tmp:
                        if fixingDate >= dict_bug_date[bugNameID]:#过滤修复时间比问题报告创建时间小的情况
                            print (bugNameID, tmp, "correct");
                            com_res = items[0];
                            vbugid.append(bugNameID);
                            vcommit.append(com_res);
                            vcreatedDate.append(dict_bug_date[bugNameID]);
                            vfixingDate.append(fixingDate);
#                             del dict_bug_date[bugNameID];
#                             rename.remove(bugNameID);
                        else:
                            print (bugNameID, tmp, "error");
                        break;
                elif summary.find('%s'%bugNameID.lower())==-1:#必须写全，因为else是就近原则
                    #summary删除[项目名-XXX]后，是否包含fix和bug id号
                    summary_remain = re.sub("\[?%s\d{1,5}\]?"%bug_name.lower(),"",summary)
    #                 summary_remain = "fix #1 apache"#调试用
                    if re.findall(r"(.*)[ _-]fix[ _-](.*)|fix[ _-](.*)|(.*)[ _-]fixed[ _-](.*)|fixed[ _-](.*)|(.*)[ _-]fixing[ _-](.*)|fixing[ _-](.*)",summary_remain,re.I) and re.findall(r"#%s"%bugNameID_ID,summary_remain):
    #                     summary_remain = "#1 apache"#调试用
                        if re.findall(r"^#%s[ .-]+"%bugNameID_ID,summary_remain):
                            summary_bugid = re.findall(r"^#%s[ .-]+"%bugNameID_ID,summary_remain)
                        elif re.findall(r"[ .-]+#%s[ .-]+"%bugNameID_ID,summary_remain):
                            summary_bugid = re.findall(r"[ .-]+#%s[ .-]+"%bugNameID_ID,summary_remain)
                        elif re.findall(r"[ .-]+#%s$"%bugNameID_ID,summary_remain):
                            summary_bugid = re.findall(r"[ .-]+#%s$"%bugNameID_ID,summary_remain)
                        summary_bugid = "".join(summary_bugid)#列表转字符串
                        summary_bugid = summary_bugid.replace(' ', '')#替换空格
                        summary_bugid = summary_bugid.replace('#', '')#替换井号
                        if summary_bugid == bugNameID_ID:
                            if fixingDate >= dict_bug_date[bugNameID]:#过滤修复时间比问题报告创建时间小的情况
                                print (bugNameID_ID, summary_bugid, "correct");
                                com_res = items[0];
                                vbugid.append(bugNameID);
                                vcommit.append(com_res);
                                vcreatedDate.append(dict_bug_date[bugNameID]);
                                vfixingDate.append(fixingDate);
#                                 del dict_bug_date[bugNameID];
#                                 rename.remove(bugNameID);
                            else:
                                print (bugNameID_ID, summary_bugid, "error");
                            break;
        
        bug_sum = len(list_bugID)
#         set_vcommit = set(vcommit)
        match_vcommit = len(vcommit)
        set_vbugid = set(vbugid)
        match_vbugid = len(set_vbugid)
        set_rename=set(rename)
        nobugid = set_rename-set_vbugid#nobugid等于rename移除被修复的bugid后剩下的bugid
        nobugid = list(nobugid)
        
#         nobugid = rename#nobugid等于rename移除被修复的bugid后剩下的bugid
        
        precision =  float(match_vbugid)/float(bug_sum)
        print (commit_sum, match_vcommit, match_vbugid, bug_sum, precision)   
        
        bug_commit = open(r'D:\workspace\mixed-workspace\mySZZ\matching_bugid_fixingsha\%s_bug_commit_all.txt'%project, 'w')     
        nobug_commit = open(r'D:\workspace\mixed-workspace\mySZZ\matching_bugid_fixingsha\%s_nocommit_all.txt'%project, 'w')   
        
        for i in range(len(vbugid)):
            bug_commit.write(vbugid[i]+' '+vcommit[i]+' '+vcreatedDate[i]+' '+vfixingDate[i])
            bug_commit.write('\n')
        
        for i in range(len(nobugid)):
            nobug_commit.write(nobugid[i]+'\n')
        
        bug_commit.close()
        nobug_commit.close()
    
    
