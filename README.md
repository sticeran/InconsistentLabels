# The replication package of inconsistent labels

## Titile: Inconsistent defect labels: essential, causes, and influence

Our work is to study the existence and influence of inconsistent labels in multi-version-project defect data sets.	The “inconsistent label” phenomenon denotes that a module in multiple versions has the same source code (non-blank, non-comment) but the corresponding instances in these versions have different labels.

## Dataset Summary

Dataset              | Project     | Versions            | #Instances (#IL-instances)     | %Defective | #Metrics
-------              | :------     | :------:            | :------------------------:     | :--------: | :-------
ECLIPSE-2007    | Eclipse     | 2.0, 2.1, 3.0       |  6,727-10,590 (91-145)         | 11%~15%    | 198
Metrics-Repo-2010	| Ant	| 1.3, 1.4, 1.5, 1.6, 1.7	| 124-740 (2-14)	| 11%~26% | 20
Metrics-Repo-2010	| Camel	| 1.0, 1.2, 1.4, 1.6	| 339-927 (28-123)	| 4%~37% |
Metrics-Repo-2010 | Forrest	| 0.6, 0.7, 0.8	| 6-30 (0-1)	| 7%~17% | 
Metrics-Repo-2010	| Jedit	| 3.2, 4.0, 4.1, 4.2, 4.3	| 259-487 (1-18)	| 2%~34% | 
Metrics-Repo-2010 | Log4j	| 1.0, 1.1, 1.2	| 103-193 (39-48)	| 29%~95% | 
Metrics-Repo-2010 | Lucene	| 2.0, 2.2, 2.4	| 186-330 (55-89)	| 49%~61% | 
Metrics-Repo-2010 | Pbeans	| 1.0, 2.0	| 26-51 (1-1)	| 20%~77% | 
Metrics-Repo-2010 | Poi	| 1.5, 2.0, 2.5, 3.0	| 235-438 (49-240)	| 12%~64% | 
Metrics-Repo-2010	| Synapse	| 1.0, 1.1, 1.2	| 157-256 (10-20)	| 10%~34% | 
Metrics-Repo-2010	| Velocity	| 1.4, 1.5, 1.6	| 195-229 (41-81)	| 34%~75% | 
Metrics-Repo-2010	| Xalan	| 2.4, 2.5, 2.6, 2.7	| 676-899 (314-481)	| 16%~99% | 
Metrics-Repo-2010	| Xerces	| Init, 1.2, 1.3, 1.4	| 162-451 (25-212)	| 15%~64% | 
JIRA-HA-2019/JIRA-RA-2019 | ActiveMQ	| 5.0.0, 5.1.0, 5.2.0, 5.3.0, 5.8.0	| 1,884-3,420 (1-136/13-282)	| 4%~8% / 6%~16% | 65
JIRA-HA-2019/JIRA-RA-2019 | Camel	| 1.4.0, 2.9.0, 2.10.0, 2.11.0	| 1,503-8,809 (3-140/4-131)	| 2%~24% / 2%~19% | 
JIRA-HA-2019/JIRA-RA-2019 | Derby	| 10.2.1.6, 10.3.1.4, 10.5.1.1	| 1,963-2,704 (42-56/163-281)	| 7%~9% / 14%~34% | 
JIRA-HA-2019/JIRA-RA-2019 | Groovy	| 1.5.7, 1.6.0.Beta 1, 1.6.0.Beta 2	| 756-883 (19-28/20-21)	| 11%~14% / 3%~9% | 
JIRA-HA-2019/JIRA-RA-2019	| HBase	| 0.94.0, 0.95.0, 0.95.2	| 1,047-1,801 (0-17/0-101)	| 6%~7% / 21%~27% | 
JIRA-HA-2019/JIRA-RA-2019 | Hive	| 0.9.0, 0.10.0, 0.12.0	| 1,319-2,512 (14-26/43-68)	| 2%~4% / 8%~19% | 
JIRA-HA-2019/JIRA-RA-2019 | JRuby	| 1.1, 1.4, 1.5, 1.7.0.preview1	| 723-1,551 (9-78/4-17)	| 10%~24% / 5%~19% | 
JIRA-HA-2019/JIRA-RA-2019 | Lucene	| 2.3.0, 2.9.0, 3.0.0, 3.1.0	| 803-1,802 (15-29/10-32)	| 14%~20% / 6%~24% | 
JIRA-HA-2019/JIRA-RA-2019 | Wicket	| 1.3.0.beta1, 1.3.0.beta2, 1.5.3	| 1,669-2,570 (0-0/0-49)	| 4%~17% / 4%~7% | 
MA-SZZ-2020 | Zeppelin	| 0.5.0, 0.5.5, 0.5.6, 0.6.0, 0.6.1, 0.6.2, 0.7.0, 0.7.1, 0.7.2, 0.7.3	| 129-413 (6-24)	| 21~38% | 44
MA-SZZ-2020	| Shiro	| 1.1.0, 1.2.0, 1.2.1, 1.2.2, 1.2.3, 1.2.4, 1.2.5, 1.2.6, 1.3.0, 1.3.1	| 381-493 (0-1)	| 4~7% | 
MA-SZZ-2020	| Maven	| 2.2.0, 2.2.1, 3.0.0, 3.0.1, 3.0.2, 3.0.3, 3.0.4, 3.0.5, 3.1.0, 3.1.1	| 318-703 (0-9)	| 4~13% | 
MA-SZZ-2020	| Flume	| 1.2.0, 1.3.0, 1.3.1, 1.4.0, 1.5.0, 1.5.1, 1.5.2, 1.6.0, 1.7.0, 1.8.0	| 272-574 (0-35)	| 4~32% | 
MA-SZZ-2020	| Mahout	| 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.10.0, 0.11.0, 0.12.0, 0.13.0	| 1027-1267 (0-1)	| 17~29% | 
IND-JLMIV+R-2020	| 38 projects	| 395 versions	| 3-1708 (0-35)	| 0~36% | 4198


# Quick Start
In our work, in addition to using existing publicly available multi-version-project defect data sets, we collected a file-level multi-version-project defect data set (MA-SZZ-2020) using our replicated MA-SZZ [1] defect collection approach.

### (1) [`/RQ1 experimental data/`](https://github.com/sticeran/InconsistentLabels/tree/master/RQ1%20experimental%20data/) The result folder of RQ1 contains the original data set (in the "original" folder) and the detection results of inconsistent labels (in the "(type)original" folder) for the six multi-version-project defect data sets we investigated: ECLIPSE-2007 [2], Metrics-Repo-2010 [3-5], JIRA-HA-2019 [6], JIRA-RA-2019 [6], MA-SZZ-2020, and IND-JLMIV+R-2020 data set [7]. Of these data sets, the former two data sets are widely used benchmark data sets in the literature, the next two are two recently pub-lished data sets in ICSE 2019, the fifth is a data set col-lected by ourselves using the state-of-the-art SZZ algo-rithm, and the last one is a recently published data set collected by a semi-automatic approach. With the ex-ception of our own newly collected MA-SZZ-2020 data sets, each data set has been cited extensively (9-817 cita-tions).

### (2) [`/RQ2 and RQ3 experimental data and program/`](https://github.com/sticeran/InconsistentLabels/tree/master/RQ2%20and%20RQ3%20experimental%20data%20and%20program/) The results folder of RQ2 and RQ3 contains clean and noise training data and test data (arff files) needed to build defect prediction models (CC vs. NC and NC vs. NN), as well as the executable JAR program. The raw results of RQ2 and RQ3 can be obtained by executing the JAR program. Please refer to the [`/RQ2 and RQ3 experimental data and program/README.md`](https://github.com/sticeran/InconsistentLabels/tree/master/RQ2%20and%20RQ3%20experimental%20data%20and%20program/README.md) file to learn how to run the JAR program.

### (3) [`/other program codes/`](https://github.com/sticeran/InconsistentLabels/tree/master/other%20program%20codes/) This folder contains the other code programs we developed that were used, including the metric extractor, TSILI (detecting inconsistent labels), and the replicated MA-SZZ algorithm. Each sub-folder in this folder contains README document. Please refer to these README documents to see how to run the corresponding programs.


If you use the MA-SZZ-2020 defect data set or the method code that this work implements, please cite our paper "Inconsistent defect labels: essential, causes, and influence", thanks.

# References
[1]	D.A. Costa, S. McIntosh, W. Shang, U. Kulesza, R. Coelho, A.E. Hassan. A framework for evaluating the results of the SZZ approach for identifying bug-introducing changes. IEEE Transactions on Software Engineering, 43(7), 2017: 641-657.  
[2] T. Zimmermann, R. Premraj, A. Zeller. Predicting defects for Eclipse. In Proceedings of the Third International Workshop on Predictor Models in Software Engineering, ser. PROM-ISE ’07. IEEE Computer Society, 2007: 9–.  
[3] M. Jureczko, D. Spinellis. Using object-oriented design met-rics to predict software defects. In Models and Methods of System Dependability. Oficyna Wydawnicza Politechniki Wrocławskiej, 2010: 69-81.  
[4] M. Jureczko, L. Madeyski. Towards identifying software project clusters with regard to defect prediction. In: Proceed-ings of the 6th International Conference on Predictive Models in Software Engineering, 2010: 1–10.  
[5] T. Menzies, B. Caglayan, E. Kocaguneli, J. Krall, F. Peters, B. Turhan. The promise repository of empirical software engi-neering data, June 2012.  
[6] S. Yatish, J. Jiarpakdee, P. Thongtanunam, C. Tan-tithamthavorn. Mining software defects: should we consider affected releases? ICSE 2019: 654-665.  
[7] S. Herbold, A. Trautsch, F. Trautsch. Issues with SZZ: An empirical assessment of the state of practice of defect predic-tion data collection. arXiv preprint arXiv:1911.08938v2, 2020.

