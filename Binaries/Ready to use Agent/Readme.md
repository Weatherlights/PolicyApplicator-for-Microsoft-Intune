This is the ready to use agent installer. You need to deploy the agent installer to your intune managed devices so the policies get applied.

The agent installer does 3 things:
* Install the following files:
  * PolicyApplicator.exe
  * PolicyAppicator.exe.config
  * PolicyApplicator.exe.wrunconfig
  * PolicyApplicator.ps1
  * Modules\XMLFile.psm1
  * Modules\Configuration.psm1
  * Modules\IniFile.psm1
  * Modules\ListFile.psm1
  * Modules\Generic.psm1
* Create two scheduled tasks that will run when intune has synchronized:
  * One task will run within the user context to apply user policies.
  * The other will run as system user to run machine policies.
* Install the code signature that was used to sign the powershell files into the trusted publisher store so the scripts can run.
