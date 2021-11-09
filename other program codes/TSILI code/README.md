To run this this script you must hava Python_3.7.6 and the Understand software installed on your system.
The script uses Understand's Python API and Python third-party libraries pandas and numpy.

# Program execution instruction:
python TSILI_v2.py
python TSILI_stage3_v2.py

TSILI is a Python script that contains program comments inside the code.  
There are two points to note before running the TSILI script:  
First, defect labels and corresponding Udb files for the target defect data set are required.  
The Udb files need additional generation: Download the project code of the target data set. For the code of the target project version, use the Understand tool to generate the Udb file.  
The file name of the data set needs to correspond to the Udb file name, such as ant-1.4.csv and ant-1.4.udb.  

Second, you need to replace the absolute path in the code with the path you use.  
For example, the absolute path of the Udb file: "D:/TSILI/udb/"; The absolute path of the defect data set (label) : "D:/TSILI/original/"; The storage path of detection results: "D:/TSILI/(TSILI)inconsistentLabel/".