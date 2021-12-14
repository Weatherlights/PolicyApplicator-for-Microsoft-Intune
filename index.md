## PolicyApplicator for Microsoft Intune

Welcome to the PolicyApplicator for Microsoft Intune, the all-you-need configuration experience for your 3rd party applications in Intune.

Configure 3rd party applications using OMA-DM by converting your existing configuration in a ready to use Intune configuration profiles. The PolicyApplicator can currently convert ini- xml-, json- and list files without any hustle aswell as registry structures.

Currently the project is in a very early stage and even though the scripts and the agent should work there is still code to be optimized, bugs to be found and documentation to be written. For now the best way to get started is to check the <a href="http://www.youtube.com/watch?v=M_W8YJvuZQ4">Demo</a>.

### Key Features

* Creates an ADMX policy template and all corresponding OMA-URIs from any ini-, xml-, json- **(NEW!)** or list file.
* You can convert registry structures to ADMX policy templates and OMA-URI sets that work without the PolicyApplicator Agent <em>(Currently limited to Strings, Dwords and MultiSZ values)</em>.
* Upload your created files to the intune console.
* Supports different operations:
  * Create: Create settings that do not exist (Ideal for recommended settings)
  * Update: Update existing settings
  * Delete: Delete existing settings
  * Replace: Create settings or overwrites them (Ideal to enforce policies)
* As a pro you can modify the configurations:
  * Use XPath to build and modify XML
  * Use JSON to build and modify JSON
  * Use Sections and Keys to modify ini files 
* Ready to use <a href="https://github.com/Weatherlights/PolicyApplicator-for-Microsoft-Intune/tree/main/Binaries/Ready%20to%20use%20Agent">MSI-/EXE-Agent</a> that you deploy using <a href="https://github.com/Weatherlights/PolicyApplicator-for-Microsoft-Intune/blob/b4632eaa412b0b688f62b8b72b2b18089ec15a20/Documentation/AgentInstallation.md">LoB App</a> or Win32
* Available on the <a href="ms-windows-store://pdp/?productid=XP99K4PMPD7JH3">Microsoft Store</a> or using Winget (PolicyApplicator)
* Works on Windows 11

### How it works
I hope the following graphic explains a little bit how the tool works:
![How it works](https://github.com/Weatherlights/PolicyApplicator-for-Microsoft-Intune/raw/main/Documentation/howitworks.png)

So there are 5 steps:
1. Convert one of your configuration files using one of the Convert-Scripts into a csv policy file.
2. Upload the csv policy file using the Invoke-CsvtoIntuneUpload.ps1 script.
3. Assign the created configuration profile from intune.
4. The configuration profile gets translated into registry settings with a technique called ADMX Ingestion.
5. The PolicyApplicator Agent translates the registry settings into the target configuration file.

## Check out the Demo

Check out this demonstration where we configure the VLC media player vlcrc configuration by capturing a reference configuration:
<p align="center">
 <a href="http://www.youtube.com/watch?v=M_W8YJvuZQ4"><img src="http://img.youtube.com/vi/M_W8YJvuZQ4/0.jpg" alt="Demo on Youtube" /></a>
</p>

## Get started

You can find the latest release <a href="https://github.com/Weatherlights/PolicyApplicator-for-Microsoft-Intune/releases">here</a> or within the Microsoft Store:
<a href="ms-windows-store://pdp/?productid=XPFFSV0VCDKTM5"><img height="72" src="https://raw.githubusercontent.com/Weatherlights/PolicyApplicator-for-Microsoft-Intune/gh-pages/English_L.png" alt="Get PolicyApplicator Conversion Kit"/></a>

Also check out the documentation <a href="https://github.com/Weatherlights/PolicyApplicator-for-Microsoft-Intune/wiki">here</a>.
