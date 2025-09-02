@echo off
echo Setting execute permissions for shell scripts...

REM 在Windows环境下，我们使用git来设置文件权限
REM 或者在WSL/Linux环境中运行以下命令

echo.
echo Please run the following commands in WSL or Linux environment:
echo.
echo chmod +x *.sh
echo chmod +x scripts/*.sh
echo chmod +x entrypoint.sh
echo.
echo Or if you have Git Bash installed:
echo.

if exist "%ProgramFiles%\Git\bin\bash.exe" (
    echo Found Git Bash, setting permissions...
    "%ProgramFiles%\Git\bin\bash.exe" -c "chmod +x *.sh"
    "%ProgramFiles%\Git\bin\bash.exe" -c "chmod +x scripts/*.sh" 
    "%ProgramFiles%\Git\bin\bash.exe" -c "chmod +x entrypoint.sh"
    echo Permissions set successfully!
) else if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" (
    echo Found Git Bash, setting permissions...
    "%ProgramFiles(x86)%\Git\bin\bash.exe" -c "chmod +x *.sh"
    "%ProgramFiles(x86)%\Git\bin\bash.exe" -c "chmod +x scripts/*.sh"
    "%ProgramFiles(x86)%\Git\bin\bash.exe" -c "chmod +x entrypoint.sh"
    echo Permissions set successfully!
) else (
    echo Git Bash not found. Please install Git for Windows or run in WSL/Linux environment.
    echo.
    echo Manual commands to run:
    echo   chmod +x *.sh
    echo   chmod +x scripts/*.sh  
    echo   chmod +x entrypoint.sh
)

echo.
echo You can now run:
echo   ./start.sh         - to start the container
echo   ./status.sh        - to check status
echo   ./logs.sh task1     - to view logs
echo   ./stop.sh          - to stop the container
echo.
pause