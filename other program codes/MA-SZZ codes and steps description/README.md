# Note that
there is currently no easy-to-run version of our replicated MA-SZZ algorithm (no easy-to-run command), and the code provided is only a reference for implementation.  
For the whole algorithm flow, please refer to the "The steps needed to generate defect data set through the replicated MA-SZZ.md" document.

The code provided at present is a non-integrated early version, which is complex and has some redundancy. The reason is that the MA-SZZ algorithm is complex (including multiple necessary steps), and we do not intend to make the replicated MA-SZZ algorithm as a focus or contribution to this work.  
In this work, the replicated MA-SZZ algorithm only serves to collect a file-level multi-version defect data set based on the SZZ algorithm.  
The replicated MA-SZZ algorithm program is developed and maintained by the first author, who is working on the optimization of the code and will release a version of the whole algorithm process implemented in Python language in the future.  
In the current version, the first author divides the entire algorithm flow of MA-SZZ into several sub-steps (such as downloading problem reports, identifying BFC, identifying BIC, linking defective modules to the version, etc.). Each sub-step corresponds to a subroutine/tool.  
These subroutines/tools are implemented in different programming languages (Java, R, Python, PowerShell) for speed and other purposes, which brings inconvenience and difficulty in use. The first author is working to consolidate the early code into a lightweight, easy-to-use whole.
