# The replication package of inconsistent labels

## Titile: An in-depth understanding of inconsistent labels in multi-version-project defect data sets

Our work is to study the existence and influence of inconsistent labels in multi-version-project defect data sets.	The “inconsistent label” phenomenon denotes that a module in multiple versions has the same source code (non-blank, non-comment) but the corresponding instances in these versions have different labels.

## Dataset Summary

Dataset              | Project     | Versions            | #Instances (#IL-instances)     | %Defective | #Metrics
-------              | :------     | :------:            | :------------------------:     | :--------: | :-------
ECLIPSE-2007 (AV)    | Eclipse     | 2.0, 2.1, 3.0       |  6,727~10,590 (99~182)         | 11%~15%    | 198

# Quick Start
In our work, in addition to using existing publicly available multi-version-project defect data sets, we collected a file-level multi-version-project defect data set (MA-SZZ-2020) using our replicated MA-SZZ defect collection approach [1].

The "/ProgramAndData/data_csv/TSILI/original/MA-SZZ-2020/" folder contains the MA-SZZ-2020 defect data set we collected.

The "/ProgramAndData/Additional Remarks/datasets/MA-SZZ-2020/MA-SZZ codes and steps description/" folder contains the code of the MA-SZZ defect collection approach we implemented based on JIRA and GitHub.

For our proposed TSILI algorithm, we expose our code (which contains comments) and place it in the "/ProgramAndData/TSILI code/" folder.


If you use the MA-SZZ-2020 defect data set or the method code that this work implements, please cite the inconsistent labels paper.

# References
[1]	D.A. Costa, S. McIntosh, W. Shang, U. Kulesza, R. Coelho, A.E. Hassan. A framework for evaluating the results of the SZZ approach for identifying bug-introducing changes. IEEE Transactions on Software Engineering, 43(7), 2017: 641-657.
