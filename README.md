# PolicyApplicator for Microsoft Intune
Configure any app you like using OMA-DM. This little tool will automatically convert configuration files (currently xml, ini and lists) into ready to use Intune configuration profiles that you can simply deploy. The tool consists out of 3 components that allow you the creation, upload and application of policies.

The powershell code -as it is published here- has been digitally signed using a public code signature.
## Key Features
* Creates an ADMX policy template and all corresponding OMA-URIs from any ini-, xml-, json- or list file.
* Creates an ADMX policy template and all corresponsing OMA-URIs from Registry Structures. This one works even without the PolicyApplicator Agent!
* Upload your created files into the intune console.
* Supports different operations:
  * Create: Create settings that do not exist
  * Update: Update existing settings
  * Delete: Delete existing settings
  * Replace: Create settings or overwrites them
* As a pro you can modify the configurations. All it takes is a little xpath/json :).

## How it works
I hope the following graphic explains a little bit how the tool works:
![How it works](/Documentation/howitworks.png)

So there are 5 steps:
1. Convert one of your configuration files using one of the Convert-Scripts into a csv policy file.
2. Upload the csv policy file using the Invoke-CsvtoIntuneUpload.ps1 script.
3. Assign the created configuration profile from intune.
4. The configuration profile gets translated into registry settings with a technique called ADMX Ingestion.
5. The PolicyApplicator Agent translates the registry settings into the target configuration file.

## Demo
Checkout this video on Youtube: [PolicyApplicator Demo](https://www.youtube.com/watch?v=M_W8YJvuZQ4)

## Documentation
Can be found in the <a href="https://github.com/Weatherlights/PolicyApplicator-for-Microsoft-Intune/wiki">Wiki</a>.
