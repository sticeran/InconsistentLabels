package com.SZZ.app;

import java.io.File;
import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.LinkedList;
import java.util.List;
import java.util.Scanner;

import org.apache.log4j.Logger;
import org.eclipse.jgit.util.FileUtils;

import com.SZZ.jiraAnalyser.Application;
import com.SZZ.jiraAnalyser.entities.Transaction;
import com.SZZ.jiraAnalyser.entities.TransactionManager;
import com.SZZ.jiraAnalyser.git.Git;
import com.SZZ.jiraAnalyser.git.JiraRetriever;

public class SZZApplication_v1 {

	/* Get actual class name to be printed on */
	
	private static String jiraAPI = "/jira/sr/jira.issueviews:searchrequest-xml/temp/SearchRequest.xml";

	public static void main(String[] args) {
//		String[] array_projectNames = { "avro", "bcel", "cassandra", "drill", "hadoop", "kafka", "openjpa", "pig", "shiro", "zookeeper" };
//		String[] array_projectNames = { "kafka", "flink", "rocketmq", "zookeeper", "zeppelin", "beam", "ignite","shiro","maven","flume" };
		String[] array_projectNames = { "zeppelin","maven","shiro","flume","mahout","geode" };
//		String[] array_projectNames = { "shiro" };
		
		String userDir = System.getProperty("user.dir");
        File file = new File(userDir);
        String strParentDirectory = file.getParent();
        String savedPath = "";
        
        args = new String[7];
        
		for (String i_projectName : array_projectNames)
		{
			args[0] = "-all";
			args[1] = "https://github.com/apache/"+i_projectName+".git";
			args[2] = "https://issues.apache.org/jira/projects/"+i_projectName;
			args[3] = i_projectName;
			
			savedPath = strParentDirectory+"\\issue_reports\\";
			savedPath += i_projectName + "\\";
	
			if (args.length == 0) {
				System.out.println("Welcome to SZZ Calculation script.");
				System.out.println("Here a guide how to use the script");
				System.out.println("szz.jar -all githubUrl, jiraUrl, jiraKey => all steps together");
			} else {
				switch (args[0]) {
				case "-all":
//					Git git;
					try {
						System.out.println(i_projectName+":Crawling issue reports from JIRA");
						String[] array = args[2].split("/jira/projects/");
						String projectName = args[3];
						String jiraUrl = array[0] + jiraAPI;
						JiraRetriever jr1 = new JiraRetriever(jiraUrl, savedPath, projectName);
						jr1.printIssues();
						System.out.println(i_projectName+":Crawling finish");
					} catch (Exception e) {
						break;
					}
//					try {
//						System.out.println(i_projectName+":git log from git");
//						Application a = new Application();
//						a.mineData(args[1], args[2].replace("{0}", args[3]), args[3], args[3]);
//						System.out.println(i_projectName+":git log finish");
//					} catch (MalformedURLException e) {
//						// TODO Auto-generated catch block
//						e.printStackTrace();
//					} catch (Exception e) {
//						// TODO Auto-generated catch block
//						e.printStackTrace();
//					}
//					System.out.println(i_projectName+":cleaning?");
//					Scanner in= new Scanner(System.in);//生成一个输入流对象
//					in.next();//等待用户输入
//					clean(args[3]);//用于把爬取的问题报告删除
//					System.out.println(i_projectName+":cleaning? finish");
					break;
				default:
					System.out.println("Commands are not in the right form! Please retry!");
					break;
				}
			}
		}//end for
		System.out.println("all finish");
	}

	private static void clean(String jiraKey) {
		for (File fileEntry : new File(".").listFiles()) {
			if (fileEntry.getName().toLowerCase().contains(jiraKey.toLowerCase())) {
				if (!fileEntry.getName().contains("Commit")) {
					try {
						if (fileEntry.isFile())
							Files.deleteIfExists(fileEntry.toPath());
						else
							deleteDir(fileEntry);
					} catch (IOException e) {
						// TODO Auto-generated catch block
						e.printStackTrace();
					}
				}
			}
		}
	}

	private static void deleteDir(File file) {
		File[] contents = file.listFiles();
		if (contents != null) {
			for (File f : contents) {
				deleteDir(f);
			}
		}
		file.delete();
	}
}
