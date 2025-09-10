
function Invoke-ListRemediation {
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

    $rule = $rules[0]
    $fileDoesNotExistYet = $false;

    $compliance = "Compliant"
    If ( Test-Path -Path $FilePath ) {
        $encoding = Get-FileEncoding -Path $FilePath;
        $list = Get-Content -Path $FilePath;
            if ( $rule.List.Count -ne $list.Count ) {
                $compliance = "Non-Compliant: List does not have the same length";
            } else {
                For ( $i = 0; $i -lt $rule.List.Count; $i++ ) {
                    if ( $rule.List[$i] -ne $list[$i] ) {
                        $compliance = "Non-Compliant: Item $i does not match";
                    }
                }
            }
        
    } else {
        $compliance = "Non-Compliant: File does not exist";
        $fileDoesNotExistYet = $true;
    }

    if ( ($compliance -ne "Compliant" ) -and ( $Action -eq "Remediate" ) -and ( ( $fileDoesNotExistYet -eq $false ) -or ( $operation -eq "create" ) -or ( $operation -eq "replace" ) ) ) {
        Out-RemediatedFile -FilePath $FilePath -InputObject $rule.List -CreateVerbose -Encoding $Encoding
 #       $compliance = "Compliant";
    }


    $compliance;
}