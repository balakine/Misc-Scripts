@ECHO OFF
REM https://technet.microsoft.com/en-us/library/cc753551.aspx
REM Delete log files older than 30 days (earlier than or equal to 31 days)
REM To limit the impact of supplying the wrong path we are making the following assumptions:
REM log files have .log extension, there are no subdirectories, logs are not open and not read-only
REM Script parameters - space separated list of paths to the files

FOR %%i IN (%*) DO (
	FORFILES /p %%i /m *.log /d -31 /c "cmd /c DEL /q @path"
)