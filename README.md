# The replication package of inconsistent labels

## Titile: An in-depth understanding of inconsistent labels in multi-version-project defect data sets

Our work is to study the existence and influence of inconsistent labels in multi-version-project defect data sets.	The “inconsistent label” phenomenon denotes that a module in multiple versions has the same source code (non-blank, non-comment) but the corresponding instances in these versions have different labels.

## Dataset Summary

Dataset              | Project     | Versions            | #Instances (#IL-instances)     | %Defective | #Metrics
-------              | :------     | :------:            | :------------------------:     | :--------: | :-------
ECLIPSE-2007 (AV)    | Eclipse     | 2.0, 2.1, 3.0       |  6,727-10,590 (99-182)         | 11%~15%    | 198
Metrics-Repo-2010 (TW)	| Ant	| 1.3, 1.4, 1.5, 1.6, 1.7	| 124-740 (2-14)	| 11%~26%
	| Camel	| 1.0, 1.2, 1.4, 1.6	| 339~927 (28~123)	| 4%~37%
	| Forrest	| 0.6, 0.7, 0.8	| 6~30 (0~1)	| 7%~17%
	| Jedit	| 3.2, 4.0, 4.1, 4.2, 4.3	| 259~487 (1~18)	| 2%~34%
	| Log4j	| 1.0, 1.1, 1.2	| 103~193 (39~48)	| 29%~95%
	| Lucene	| 2.0, 2.2, 2.4	| 186~330 (55~89)	| 49%~61%
	| Pbeans	| 1.0, 2.0	| 26~51 (1~1)	| 20%~77%
	| Poi	| 1.5, 2.0, 2.5, 3.0	| 235~438 (49~240)	| 12%~64%
	| Synapse	| 1.0, 1.1, 1.2	| 157~256 (10~20)	| 10%~34%
	| Velocity	| 1.4, 1.5, 1.6	| 195~229 (41~81)	| 34%~75%
	| Xalan	| 2.4, 2.5, 2.6, 2.7	| 676~899 (314~481)	| 16%~99%
	| Xerces	| Init, 1.2, 1.3, 1.4	| 162~451 (25~212)	| 15%~64%
JIRA-HA-2019 (TW)
/JIRA-RA-2019 (AV)	ActiveMQ	5.0.0, 5.1.0, 5.2.0, 5.3.0, 5.8.0	1,884~3,420 (1~136/13~282)	4%~8% / 6%~16%
	Camel	1.4.0, 2.9.0, 2.10.0, 2.11.0	1,503~8,809 (3~140/4~131)	2%~24% / 2%~19%
	Derby	10.2.1.6, 10.3.1.4, 10.5.1.1	1,963~2,704 (45~69/174~294)	7%~9% / 14%~34%
	Groovy	1.5.7, 1.6.0.Beta 1, 1.6.0.Beta 2	756~883 (19~28/20~21)	11%~14% / 3%~9%
	HBase	0.94.0, 0.95.0, 0.95.2	1,047~1,801 (0~19/0~104)	6%~7% / 21%~27%
	Hive	0.9.0, 0.10.0, 0.12.0	1,319~2,512 (14~26/49~75)	2%~4% / 8%~19%
	JRuby	1.1, 1.4, 1.5, 1.7.0.preview1	723~1,551 (10~79/4~17)	10%~24% / 5%~19%
	Lucene	2.3.0, 2.9.0, 3.0.0, 3.1.0	803~1,802 (16~29/10~32)	14%~20% / 6%~24%
	Wicket	1.3.0.beta1, 1.3.0.beta2, 1.5.3	1,669~2,570 (0~0/0~51)	4%~17% / 4%~7%
MA-SZZ-2020 
(SZZ-based)	Zeppelin	0.5.0, 0.5.5, 0.5.6, 0.6.0, 0.6.1, 0.6.2, 0.7.0, 0.7.1, 0.7.2, 0.7.3	129~413 (7~25)	1~35%
	Shiro	1.1.0, 1.2.0, 1.2.1, 1.2.2, 1.2.3, 1.2.4, 1.2.5, 1.2.6, 1.3.0, 1.3.1	381~493 (20~31)	4~7%
	Maven	2.2.0, 2.2.1, 3.0.0, 3.0.1, 3.0.2, 3.0.3, 3.0.4, 3.0.5, 3.1.0, 3.1.1	318~703 (0~51)	5~12%
	Flume	1.2.0, 1.3.0, 1.3.1, 1.4.0, 1.5.0, 1.5.1, 1.5.2, 1.6.0, 1.7.0, 1.8.0	272~574 (27~90)	4~30%
	Mahout	0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.10.0, 0.11.0, 0.12.0, 0.13.0	1027~1267 (32~88)	13~29%


# Quick Start
In our work, in addition to using existing publicly available multi-version-project defect data sets, we collected a file-level multi-version-project defect data set (MA-SZZ-2020) using our replicated MA-SZZ defect collection approach [1].

The "/ProgramAndData/data_csv/TSILI/original/MA-SZZ-2020/" folder contains the MA-SZZ-2020 defect data set we collected.

The "/ProgramAndData/Additional Remarks/datasets/MA-SZZ-2020/MA-SZZ codes and steps description/" folder contains the code of the MA-SZZ defect collection approach we implemented based on JIRA and GitHub.

For our proposed TSILI algorithm, we expose our code (which contains comments) and place it in the "/ProgramAndData/TSILI code/" folder.


If you use the MA-SZZ-2020 defect data set or the method code that this work implements, please cite the inconsistent labels paper.

# References
[1]	D.A. Costa, S. McIntosh, W. Shang, U. Kulesza, R. Coelho, A.E. Hassan. A framework for evaluating the results of the SZZ approach for identifying bug-introducing changes. IEEE Transactions on Software Engineering, 43(7), 2017: 641-657.
