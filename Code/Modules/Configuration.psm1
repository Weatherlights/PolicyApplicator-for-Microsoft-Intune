function Get-PolicyApplicatorConfiguration {
   <#  
    .Synopsis  
        Builds a config object from the registry.
          
    .Description  
        Gets the PolicyApplicator configuration from the registry and parses it into an object that later can be used to write into the specific files.
          
    .Notes  
        Author        : Hauke Goetze
      
        Version        : 1.0 - 2021/03/22 - Started with this version table.        
     
          
    .Inputs  
        System.String  
          
    .Outputs  
        System.Array
          
    .Parameter RegistryPath  
        Specifies the path of the registry where the function should search for PolicyApplicator PolicySets.
          
    .Example  
        $configs = Get-PolicyApplicatorConfiguration "HKLM:\Software\Policies\PolicyApplicator" 
        -----------  
        Description  
        Searches in the registry key for PolicySets and stores them in the configs array.
    #>  
param(
        [ValidateNotNullOrEmpty()]  
        [ValidateScript({Test-Path $_})]  
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
        [string]$RegistryPath
)
$config = @();

$registryKeys = Get-ChildItem -Recurse -Path $RegistryPath | WHERE { $_.PSChildName.StartsWith("PolicySet:") }
forEach ( $registryKey in $registryKeys ) {
    if ( $registryKey.PSChildName.StartsWith("PolicySet:") ) {

        $FileType = $registryKey.GetValue("Mode")
        if ( $registryKey.GetValue("operation") ) {
            $fileOperation = $registryKey.GetValue("operation");
        } else {
            if ( $registryKey.GetValue("CreateFile") ) {
                $fileOperation = "create";
            } else {
                $fileOperation = "update";
            }
        }

        $FilePath = $registryKey.GetValue("Path");
        $Encoding = $registryKey.GetValue("Encoding");

        #### Resolve system variables tagged with %-symbol
        Select-String -Pattern '\%(.+?)\%' -InputObject $FilePath -AllMatches |
            ForEach-Object {$_.Matches} |
                ForEach-Object  {
                $variable = $_.Groups[1].Value

                $resolvedVariabel = [System.Environment]::GetEnvironmentVariable($variable)
                $resolvedVariabel
                $FilePath = $filepath -replace "%$variable%", $resolvedVariabel
            } 


        $rules = @();

        $registryKeyNames = $registryKey.GetSubKeyNames() | sort { [int]($_ -replace '\D')}

        ForEach ( $registryKeyName in $registryKeyNames ) {
            $configKey = $registryKey.OpenSubKey($registryKeyName)

            switch ( $FileType ) {
                "ini" {
                    $iniSection = $configKey.GetValue("section");
                    $iniKey = $configKey.GetValue("key");
                    $iniValue = $configKey.GetValue("value");
                    $iniOperation = $configKey.GetValue("operation");
                    
                    $rule = @{
                        "Section" = $iniSection;
                        "Key" = $iniKey;
                        "Value" = $iniValue;
                        "Operation" = $iniOperation;
                    }

                    $rules += $rule;
                }
                "list" {
                    
                    
                    $operation = $configKey.GetValue("operation");

                    $list = @()
                    $listKey = $configKey.OpenSubKey("list")
                    if ( $listKey ) {
                        ForEach ( $listKeyName in $listKey.GetValueNames() ) {
                            $list += $listKey.GetValue($listKeyName)
                        }
                    }

                    $rule = @{
                        "operation" = $operation;
                        "list" = $list;
                    }

                    $rules += $rule;
                }
                "xml" {
                    $xpath = $configKey.GetValue("xpath");
                    $value = $configKey.GetValue("value");
                    $operation = $configKey.GetValue("operation");

                    $namespace = @{}
                    $namespaceKey = $configKey.OpenSubKey("namespace")
                    if ( $namespaceKey ) {
                        ForEach ( $namespaceKeyValue in $namespaceKey.GetValueNames() ) {
                            $namespace[$namespaceKeyValue] = $namespaceKey.GetValue($namespaceKeyValue);
                        }
                    }

                    $rule = @{
                        "xpath" = $xpath;
                        "value" = $value;
                        "Operation" = "$operation";
                        "Namespace" = $namespace;
                    }

                    $rules += $rule;
                }
                "json" {
                    
                    $jsonPath = $configKey.GetValue("JSONPath");
                    $value = $configKey.GetValue("value");
                    $operation = $configKey.GetValue("operation");
                    $DataType = $configKey.GetValue("DataType");
 

                    $rule = @{
                        "JSONPath" = $jsonPath;
                        "value" = $value;
                        "Operation" = "$operation";
                        "DataType" = $DataType
                    }

                    $rules += $rule;
                }
            }
        }

        $fileConfig = @{ "FileType" = $FileType; "FilePath" = $FilePath; "Operation" = $fileOperation; "Encoding" = $Encoding; "Rules" = $rules }
        if ( $FileType -ne "Disabled" ) {
            $config += $fileConfig
        }
    }
}
    $config;
}