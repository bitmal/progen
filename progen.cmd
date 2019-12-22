@echo off
rem Use this script to manage projects and their solutions



set "cmd_path=%~p0"
set "config_file=%~n0.txt"

if not [%progen_init%] == [true] (
	set "path=%cmd_path%;%path%"
	cd %cmd_path%
	set "progen_init=true"
	echo Progen Initialized.
	goto :eof
)

setlocal EnableDelayedExpansion

set /A "arg_length=0"
for %%A in (%*) do (
	set "arg[!arg_length!]=%%~A"
	set /A "arg_length+=1"
)

pushd %cmd_path%

if not exist %config_file% (
	type NUL > %config_file%
)
call :erase_duplicates
call :load_config

if %arg_length% GTR 0 (
	if !arg[0]!'==/list' (
		call :list_projects
	) else ( if !arg[0]!'==/load' (
		call :load_project
	) else ( if !arg[0]!'==/add' (
		call :add_project
	) else ( if !arg[0]!'==/build' (
		call :build_project !arg[1]!
	) else ( if !arg[0]!'==/regen' (
		if %arg_length% GTR 1 (
			call :generate_project_files !arg[1]!
		)
	) else ( if !arg[0]!'==/git-status' (
		call :git_status !arg[1]!
	) else (
		echo Invalid command.
	))))))
)
popd
setlocal DisableDelayedExpansion
goto :eof


:git_status
	set "project=%~1"

	pushd %CD%\%project%
	git status
	popd	
exit /B

:ssh_git_init
	if %arg_length% GTR 0 (
		set "sshfile=%~1"
		eval $(ssh-agent -s) > NUL
		ssh-add %sshfile%
	) else (
		echo User must provide a valid ssh token file to init agent.
	)
exit /B

:load_config
	set /A projects_length=0
	for /F "tokens=*" %%A in (%config_file%) do (
		set project[!projects_length!]=%%A
		set /A projects_length+=1
	)
exit /B

:project_added
	set result=false
	for /F "tokens=*" %%A in ('findstr /R /C:"\<%~1\>" %config_file%') do (
		set result=true
		break
	)
	set %~2=!result!
exit /B

:project_exists
	set result=false
	if exist %~1 (
		set result=true
	)
	set %~2=!result!
exit /B

:build_project
	if !arg_length! LEQ 1 (
		echo Cannot build a nameless project.
		goto :eof
	)
	set "project=!arg[1]!"

	call :project_added !project! isAdded
	call :project_exists !project! isExist

	set found=false
	if [!isExist!]==[true] (
		if [!isAdded!]==[true] (
			call %CD%\!project!\progen\_build.cmd
			set found=true
		) else (
			echo Project "!project!" has not been added. Cannot build.
		)
	) else (
		if [!isAdded!]==[true] (
			echo Reference is broken. Removing reference from config.
			call :erase_from_config !project!
		)
	)
	if [%found%]==[false] (
		echo Project "!project!" not found. Cannot build.
	)
exit /B

:list_projects
	more %config_file%
exit /B

:generate_project_files
	set "project=%~1"
	set "projectdir=%CD%\%project%"
	set "builddir=%CD%\build\%project%"
	set "miscdir=%projectdir%\misc"
	set "progendir=%projectdir%\progen"
	set "scriptsdir=%projectdir%\scripts"
	set "srcdir=%projectdir%\src"

	if not exist %projectdir% (
		mkdir %projectdir%
	)
	if not exist %builddir% (
		if not exist %CD%\build (
			mkdir %CD%\build
		)
		mkdir %builddir%
	)
	if not exist %miscdir% (
		mkdir %miscdir%
	)
	if not exist %progendir% (
		mkdir %progendir%
	)
	if not exist %scriptsdir% (
		mkdir %scriptsdir%
	)
	if not exist %srcdir% (
		mkdir %srcdir%
	)

	rem PROGEN ENVIRONMENT VIMRC
	(
		echo " PROGEN ENVIRONMENT VIMRC
		echo " ------------------------
		echo " This VIMRC is used on environment launch
		echo.
		echo set nocompatible
		echo source ~\Vim\_vimrc
		echo let g^:project="%project%"
		echo let g^:projectdir="%projectdir%"
		echo let g^:scriptsdir="%scriptsdir%"
		echo let g^:srcdir="%srcdir%"
		echo let g^:miscdir="%miscdir%"
		echo let g^:builddir="%builddir%"
		echo let g^:progendir="%progendir%"
		echo cd %projectdir%
		echo noremap ^<silent^>^<M-m^>  ^<ESC^> ^:make^<CR^>^:cope
		echo noremap ^<silent^>^<M-r^>  ^<ESC^> ^:call Run^(^) ^<CR^>
		echo noremap ^<silent^>^<M-d^>  ^<ESC^> ^:call Debug^(^)^<CR^>
		echo set makeprg=call^\ progen^\ ^/build^\ %project%
		echo let g:runCmd="^!devenv /RunExit ".$builddir."\\".$project.".exe"
		echo let g^:debugCmd="^!devenv /NoSplash /Command \"Debug.StepInto\" /DebugExe ".$builddir."\\".$project.".exe"
		echo func Run^(^)
		echo   execute g^:runCmd
		echo endfunction
		echo func Debug^(^)
		echo   execute g^:debugCmd
		echo endfunction
		echo source %scriptsdir%\%project%.vimrc
	) > %progendir%\_%project%.vimrc

	if not exist %scriptsdir%\%project%.vimrc (
		rem PROJECT ENVIRONMENT VIMRC
		(
			echo " PROJECT ENVIRONMENT VIMRC
			echo " -------------------------
			echo.
		) > %scriptsdir%\%project%.vimrc
	)

	rem ENVIRONMENT LAUNCHER & INITIALIZER
	(
		echo ^@echo off
		echo.
		echo rem ENVIRONMENT LAUNCHER ^& INITIALIZER
		echo rem ----------------------------------
		echo rem This command launches the environment and sets up the environment
		echo.
		echo set "project=%project%"
		echo set "projectdir=%projectdir%"
		echo set "builddir=%builddir%"
		echo set "miscdir=%miscdir%"
		echo set "progendir=%progendir%"
		echo set "scriptsdir=%scriptsdir%"
		echo set "srcdir=%srcdir%"
		echo cd %projectdir% ^& "c:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" x64 ^& call gvim "%projectdir%" -u "%progendir%/_%project%.vimrc" 
	) > %progendir%\_%project%.cmd

	if not exist %scriptsdir%\%project%.cmd (
		rem PROJECT ENVIRONMENT INITIALIZER
		(
			echo rem PROJECT ENVIRONMENT INITIALIZER
			echo rem -------------------------------
			echo.
		) > %scriptsdir%\%project%.cmd
	)

	rem BUILD LAUNCHER
	(
		echo ^@echo off
		echo.
		echo rem BUILD LAUNCHER
		echo rem --------------
		echo rem This command launches the build
		echo.
		echo set "project=%project%"
		echo set "projectdir=%projectdir%"
		echo set "builddir=%builddir%"
		echo set "miscdir=%miscdir%"
		echo set "progendir=%progendir%"
		echo set "scriptsdir=%scriptsdir%"
		echo set "srcdir=%srcdir%"
		echo if not exist %CD%\build ^(
		echo 	mkdir %CD%\build
		echo ^)
		echo if not exist %builddir% ^(
		echo 	mkdir %builddir%
		echo ^)
		echo call %scriptsdir%\build.cmd
		echo echo.
		echo if errorlevel 0 ^(
		echo	 echo "%project%" was successfully built.
		echo 	 exit ^/B 0
		echo ^) else ^(
		echo 	 echo "%project%" failed being built.
		echo 	 exit ^/B -1
		echo ^)
	) > %progendir%\_build.cmd

	if not exist %scriptsdir%\build.cmd (	
		rem PROJECT BUILD
		(
			echo rem PROJECT BUILD
			echo rem -------------
			echo rem This script is called by the parent project build script.
			echo rem Add your build instructions here.
			echo.
			echo.
			echo.
			echo exit ^/B 0
		) > %scriptsdir%\build.cmd
	)

	echo Project files for "%project%" have successfully been ^(re^)generated.
exit /B

:add_project
	if !arg_length! LEQ 1 (
		echo Cannot add a nameless project.
		goto :eof
	)
	set "project=!arg[1]!"

	call :project_added !project! isAdded
	call :project_exists !project! isExist

	set canadd=false
	if [!isExist!]==[false] (
		set canadd=true
	)
	if [!isAdded!]==[false] (
		echo !project! >> %config_file%
		echo Project "!project!" was added to config.
	)

	if [!canadd!] == [true] (
		call :generate_project_files !project!
	) else (
		echo Will not generate project files for "!project!". Project directory already exists. See regen command if necessary.
	)
exit /B

:load_project
	if %arg_length% GTR 1 (	
		set project=!arg[1]!
		set "found=false"
		
		call :project_added !project! found

	) else (
		echo No project was specified. Cannot continue.
		goto :eof
	)

	if !found!'==true' (
		if exist !project! (
			echo Project "!project!" found. Loading.
			start "cmd" %CD%\!project!\progen\_!project!.cmd
		) else (
			echo Project reference broken for "!project!". Erasing all reference.
			call :erase_from_config !project!
		)
	) else (
		echo Project not found. Cannot load "!project!".
	)
exit /B

:erase_duplicates
	for /F "tokens=*" %%A in (%config_file%) do (
		call :erase_from_config %%A
		if exist progen-temp2.txt (
			(findstr /R /C:"\<%%A\>" progen-temp2.txt) > NUL
			if errorlevel 1 (
				echo:%%A>>progen-temp2.txt
			)
		) else (
			echo:%%A>>progen-temp2.txt
		)
	)

	if exist progen-temp2.txt (
		type progen-temp2.txt>progen.txt
		del progen-temp2.txt
	)
exit /B

:erase_from_config
	(findstr /R /C:"\<%~1\>" %config_file%)>progen-temp.txt

	if not errorlevel 1 (
		for /F "tokens=*" %%A in (%config_file%) do (
			set canadd=true

			for /F "tokens=*" %%B in (progen-temp.txt) do (
				if [%%B]==[%%A] (
					set canadd=false
					break
				)
			)

			if [!canadd!]==[true] (
				echo:%%A>>progen-temp1.txt
			)
		)
	) else (
			type NUL > progen.txt
	)
	
	if exist progen-temp1.txt (
		type progen-temp1.txt>progen.txt
		del progen-temp1.txt
	)

	del progen-temp.txt
exit /B
