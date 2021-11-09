To run this this script you must hava the Understand software installed on your system. The script is developed based on the Understand's Perl API.
This script is a metric extractor from one of our earlier work [1] with instructions for how to start (run instruction, input and output) in its header. The input to the program is a Udb file for the target project (version) and the output is dozens of metrics for each Java class in the target project (version)  (csv file).

# Program execution instruction:
uperl qm_java.pl -db file_db -out outPutFile

Note that to run qm_java.pl, you need to use the UPerl interpreter in Understand to execute. Of the four parameters, file_db and outPutFile are required. The file_db is the full path of the Udb file, and outPutFile is the full storage path of the output result.
For example, uperl qm_java.pl -db D:/udb/kafka/kafka-2.1.1.udb -out D:/kafka/metrics.csv

# References
[1] Y. Zhou, K.N.L Hareton, B. Xu. Examining the potentially confounding effect of class size on the associations between object-oriented metrics and change-proneness. IEEE Transactions on Software Engineering, 35(5), 2009: 607-623.