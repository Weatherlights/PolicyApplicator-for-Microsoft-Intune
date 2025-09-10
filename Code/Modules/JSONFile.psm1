function Test-JSONPathValueOnContent {
<#
.SYNOPSIS
    Tests for an json node value.
.DESCRIPTION
    This function tests an json node for a value. The json node can be selected by providing an JSONPath query.
.PARAMETER Xml
    The json document that you want to evaluate
.PARAMETER XPath
    The json to the node of the json document that you want to evaluate.
.PARAMETER Value
    The value that you want to test against.
.OUTPUTS
    bool
.NOTES
    Created by Hauke Goetze
.LINK
    https://policyapplicator.weatherlights.com
#>
    param(
        $InputObject,
        [Parameter(Mandatory=$True)][string]$JSONPath,
        [string]$Value
    )

    $Nodes = ConvertFrom-Json $JSONPath
     
    $CurrentObject = $InputObject;

    $result = $true;
    $i = 0;

    while ( $result -and ( $i -lt $Nodes.Count ) ) {
        $NodeName = $Nodes[$i];
        $NodeTypePrev = $Nodes[$i].GetType().Name;
        if ( $i -lt $Nodes.Count-1 ) {
            $NodeType = $Nodes[$i+1].getType().Name
        }

        switch ( $NodeTypePrev ) {
            "String"  {
                  if ( !$CurrentObject.$NodeName ) {
                    $result = $false;
                  } else {
                    $CurrentObject = $CurrentObject.$NodeName;
                  }
             }
             "Int32" {
                  if ( !$CurrentObject[$NodeName] ) {
                    $result = $false;
                  } else {
                    $CurrentObject = $CurrentObject[$NodeName];
                  }
             }
         }
         $i++;
    }
    if ( $result ) {
        if ( $CurrentObject -ne $Value ) {
            $result = $false;
        }
    }
    return $result;

}


function Invoke-ParseObjectStructure {
    param(
        $InputObject,
        $CurrentPath
    )
    $OutValue = "";

    $DataType = $InputObject.GetType().Name;
 
    switch ( $InputObject.GetType().Name ) {
       "Object[]" {
            
            For ( $i = 0; $i -lt $InputObject.Count; $i++ ) {
                $NewPath = $CurrentPath + "$i,";
                
                Invoke-ParseObjectStructure -InputObject $InputObject[$i] -CurrentPath $newPath -Elements $Elements
            }
            
        }
        "PSCustomObject" {
            ForEach ( $noteProperty in (Get-Member -InputObject $InputObject | WHERE { $_.MemberType -eq "NoteProperty"} ) ) {           
                $notePropertyName = $noteProperty.Name
                $newPath = $CurrentPath + "`"$notePropertyName`",";
                Invoke-ParseObjectStructure -InputObject $InputObject.$notePropertyName -CurrentPath $newPath -Elements $Elements;
            }
        } default {
            $CurrentPath = $CurrentPath -replace ",$";
            $CurrentPath += "]";
            $FinalPath = $CurrentPath;
            @{
                "Path" = $FinalPath;
                "Value" = $InputObject
            };
        }

   }
}

function Invoke-ParseJSonStructure {
<#
.SYNOPSIS
    Parses a JSON string into a path like structure
.DESCRIPTION
    This function parses a JSON object into a path like structure that can be reassembled with the Set-JSonNodeByJsonPath
.PARAMETER InputObject
    The JSON string you want to translate
.OUTPUTS
    Object[]
.NOTES
    Created by Hauke Goetze
.LINK
    https://policyapplicator.weatherlights.com
#>
    param(
        [string]$InputObject
    )

    $object = ConvertFrom-Json $InputObject

    $Elements = Invoke-ParseObjectStructure -InputObject $object -CurrentPath "[";

    return $Elements

}


function Set-JSonNodeByJsonPath {
    param(
        [Parameter(Mandatory=$True)]$Path, 
        $Value,
        [ValidateSet("Create","Update", "Replace", "Delete")]  
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()][string]$Operation,  
        $InputObject
    )

    $Nodes = ConvertFrom-Json $Path

    # Handle the empty object case
    if ( !$InputObject ) {
        $NodeName = $Nodes[0];
        $NodeType = $Nodes[0].getType().Name
        switch ( $NodeType ) {
            "String"  {
                  $InputObject = @{};
             }
            "Char"  {
                  $InputObject = @{};
             }
             "Int32" {
                $InputObject = [System.Collections.ArrayList]@($null,$null)
             }
             default {
                return $Value;
             }
         }
    }

    $CurrentObject = $InputObject;
    $ObjectToSet = $null;

    # Browse through the structure and build missing elements.
    if ( $Nodes.Count -gt 1 ) {
        For ( $i = 0; $i -lt $Nodes.Count-1; $i++ ) {
            $NodeName = $Nodes[$i];
            $NodeType = $Nodes[$i+1].getType().Name
            if ( !$CurrentObject[$NodeName] ) {
                if  ( $Operation -eq "Create" -or $Operation -eq "Replace" ) {                
                    if ( $CurrentObject.GetType().Name -eq "ArrayList" ) {
                        while ( $CurrentObject.Count -le $NodeName ) {
                            $CurrentObject.Add($null) | Out-Null
                        }
                    }
                    switch ( $NodeType ) {
                        "String"  {
                            $CurrentObject[$NodeName] = @{};
                        }
                        "Int32" {
                            $CurrentObject[$NodeName] = [System.Collections.ArrayList]@()
                        }
                        default {
                            $CurrentObject[$NodeName] = "";
                        }
                    }
                } else {
                    return $InputObject;
                }
            }
           $CurrentObject = $CurrentObject[$NodeName];
           
        }
    } else {
        $i = 0;
    }
    $ObjectToSet = $CurrentObject;

    # Modify the target element
    $NodeName = $Nodes[$i];
    $NodeType = $Nodes[$i].getType().Name
    if ( $Operation -eq "Delete" ) {
        switch ( $objecttoset.GetType().Name ) {
            "ArrayList" {
                $ObjectToSet.RemoveAt($NodeName);
            } default {
                $ObjectToSet.Remove($NodeName);
            }
        }
    } else {
        if ( !$ObjectToSet.$NodeName -or $Operation -eq "Replace" -or $Operation -eq "Update" ) { 
                if ( $ObjectToSet.GetType().Name -eq "ArrayList" ) {
                    while ( $ObjectToSet.Count -le $NodeName ) {
                        $ObjectToSet.Add($null) | Out-Null
                    }
                    
                }
            $ObjectToSet[$NodeName] = $Value;
        }
    }
    return $InputObject
}



function Invoke-JSONRemediation {
<#
.SYNOPSIS
    Detects and remediates missmatches in JSON
.DESCRIPTION
    This function takes a ruleset and matches it against a given json document. If the function runs in remediation mode the json content will be modified according to the ruleset.
.PARAMETER Action
    Defines wether the function will just detect missmatches or remediates them.
.PARAMETER FilePath
    The path to the json file you want to test and remediate.
.PARAMETER Encoding
    The encoding of the json file in case it needs to be created.
.PARAMETER Rules
    The set of remediation rules you want to match against the json document.
.PARAMETER Operation
    Specifies what you want to do with the selected file (Create, update or replace).
.NOTES
    Created by Hauke Goetze
.LINK
    https://policyapplicator.weatherlights.com
#>
param (
        [ValidateSet("Detect","Remediate")]  
        [Parameter()]  
        [string]$Action = "Detect",  


        [ValidateNotNullOrEmpty()]  
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
        [string]$FilePath,

        [ValidateSet("Unicode","UTF7","UTF8","UTF32","ASCII","BigEndianUnicode","Default","OEM")]  
        [Parameter()]  
        [string]$Encoding = "Unicode", 

        [ValidateNotNullOrEmpty()][Parameter(Mandatory=$True)][System.Array]$Rules,

        [ValidateSet("create","update","replace")][string]$Operation = "create"

);
    $Compliance = "Compliant";
    $fileDoesNotExistYet = $false;
    $newJsonObj = $null;

    #try {
            if ( Test-Path -Path $FilePath ) {
                $encoding = Get-FileEncoding -Path $FilePath;
                $json = Get-Content -Path $FilePath -Encoding $encoding -Raw
                $jsonobj = ConvertFrom-Json $json;

                forEach ( $rule in $Rules ) {
                    if ( !(Test-JSONPathValueOnContent -InputObject $jsonobj -JsonPath $rule.JSONPath -Value $rule.Value) ) {
                        $Compliance = "Non-Compliant: Element missmatch!"
                    }
                }

            } else {
                $jsonobj;
                $fileDoesNotExistYet = $true;

                $Compliance = "Non-Compliant: File does not exist!"
            }
            

            if ( $Compliance -ne "Compliant" ) {
                switch ( $Operation ) {
                    "Create" {
                    # In case the file exist merge it with the ruleset.
                        if ( !$fileDoesNotExistYet ) {
                            $RecreateFileRules = Invoke-ParseJSonStructure -InputObject $json;
                            ForEach ( $rule in $RecreateFileRules ) {
                                
                                $newJsonObj = Set-JSonNodeByJsonPath -Path $rule.Path -InputObject $newJsonObj -Value $rule.Value -Operation Create;
                            }
                        }
                        ForEach ( $rule in $Rules ) {
                            $ruleValueAsDataType = Convert-StringToJsonDataType -InputObject $rule.Value -DataType $rule.DataType;
                            $newJsonObj = Set-JSonNodeByJsonPath -InputObject $newJsonObj -Path $rule.JSONPath -value $ruleValueAsDataType -Operation $rule.Operation;
                        }

                    }
                    "Replace" {
                    # Recreate file from scratch.
                        ForEach ( $rule in $Rules ) {
                            $ruleValueAsDataType = Convert-StringToJsonDataType -InputObject $rule.Value -DataType $rule.DataType;
                            $newJsonObj = Set-JSonNodeByJsonPath -InputObject $newJsonObj -Path $rule.JSONPath -value $ruleValueAsDataType -Operation $rule.Operation;
                        }
                        
                    }
                    "Update" {
                    # Only modify anything if the file already exists.
                        if ( !$fileDoesNotExistYet ) {
                            $RecreateFileRules = Invoke-ParseJSonStructure -InputObject $json;
                            ForEach ( $rule in $RecreateFileRules ) {
                                $newJsonObj = Set-JSonNodeByJsonPath -Path $rule.Path -InputObject $newJsonObj -Value $rule.Value -Operation Create;
                            }
                            ForEach ( $rule in $Rules ) {
                                $ruleValueAsDataType = Convert-StringToJsonDataType -InputObject $rule.Value -DataType $rule.DataType;
                                $newJsonObj = Set-JSonNodeByJsonPath -InputObject $newJsonObj -Path $rule.JSONPath -value $ruleValueAsDataType -Operation $rule.Operation;
                            }
                        }
                    }
                }

                if ( $newJsonObj -and $Action -eq "Remediate" ) {
                    # Create the path to the file in case it does not exist
                    if ( !(Test-Path -Path "$Filepath\..") ) {
                        New-Item -Path $Filepath\.. -ItemType Directory
                    }
                    # Write the new json file to disk.
                    Out-File -FilePath $FilePath -InputObject (ConvertTo-Json $newJsonObj -Depth 99) -Encoding $encoding -Force
                    # Reset compliance state since everything has been remediated.
                    $Compliance = "Compliant"
                }
            }

      #  } catch {
       #     Write-Host "OHOH!"
      #          $compliance = "Non-Compliant: Unknown error occured"
       # }
       return $Compliance
}

function Convert-StringToJsonDataType {
param(
    [string]$InputObject,
    [ValidateSet("Boolean","Int32","String","Decimal")][string]$DataType
)

    if ( $DataType -eq "Boolean" ) {
        if ( $InputObject -eq "True" ) {
            return $true;
        } elseif ( $InputObject -eq "False" ) {
            return $false;
        }
        else {
            throw "Invalid Input format"
        }
    } elseif ( $DataType -eq "Int32" ) {
        return [Int32]$InputObject
    }  elseif ( $DataType -eq "Decimal" ) {
        return [Decimal]$InputObject
    } else {
        return $InputObject;
    }
}