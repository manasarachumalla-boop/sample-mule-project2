@echo off
cd /d "c:\Users\manasa.d.rachumalla\Desktop\sample-mule-project2"
echo === Pulling remote changes (rebase) ===
git pull --rebase origin feature/sample-mule-project2
if %ERRORLEVEL% neq 0 (
    echo ERROR: Rebase failed. Aborting.
    git rebase --abort
    exit /b 1
)
echo === Pushing to origin/feature/sample-mule-project2 ===
git push origin feature/sample-mule-project2
echo === Push result: %ERRORLEVEL% ===
echo === Final log ===
git log --oneline -4
echo === Done ===