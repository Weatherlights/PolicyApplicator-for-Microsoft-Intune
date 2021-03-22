## Manage (nearly) all 3rd Party Apps with OMA-DM

Welcome to the PolicyApplicator to Microsoft Intune, the 360 degree configuration experience for 3rd party applications in Intune.

Configure 3rd party applications using OMA-DM by converting your existing configuration in a ready to use Intune configuration profile. The PolicyApplicator can currently convert ini-, xml- and list files without any hustle. We hope to add reg- and json file support in not to distant future.

Currently the project is in a very early stage and even though the scripts and the agent should work there is still code to be optimized, bugs to be found and documentation to be written. For now the best way to get started is to check the <a href="http://www.youtube.com/watch?v=M_W8YJvuZQ4">Demo</a>.

### Key Features

* Creates an ADMX policy template and all corresponding OMA-URIs from any ini-, xml- or list file.
* Upload your created files to the intune console.
* Supports different operations:
  * Create: Create settings that do not exist (Ideal for recommended settings)
  * Update: Update existing settings
  * Delete: Delete existing settings
  * Replace: Create settings or overwrites them (Ideal to enforce policies)
* As a pro you can modify the configurations:
  * Use XPath to build and modify XML
  * Use Sections and Keys to modify ini files 

### Check out the Demo!

Check out this demonstration where we configure the VLC media player vlcrc configuration by capturing a reference configuration:
<p align="center">
 <a href="http://www.youtube.com/watch?v=M_W8YJvuZQ4"><img src="http://img.youtube.com/vi/M_W8YJvuZQ4/0.jpg" alt="Demo on Youtube" /></a>
</p>

### Want to try out yourself?

You can find the latest release <a href="https://github.com/Weatherlights/PolicyApplicator-for-Microsoft-Intune/releases">here</a>.
