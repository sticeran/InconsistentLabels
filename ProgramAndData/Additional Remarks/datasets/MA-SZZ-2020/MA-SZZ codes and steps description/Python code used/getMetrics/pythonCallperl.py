import subprocess

def callCP(file_parameter_db, output):
    uperlPath = r"D:\software\programming_software\data_analysis_tool\Understand\SciTools\bin\pc-win64\uperl"#试试加不加exe
    perlProgramPath = "D:/workspace/mixed-workspace/mySZZ/GetMetrics/qm_java.pl";
    
    arg1 = "-db";
    file_db = file_parameter_db;
    arg2 = "-out";
    outPutFile = output;
    
    subprocess.call([uperlPath, perlProgramPath, arg1, file_db, arg2, outPutFile])# 注意路径,如果文件夹为空则不行

