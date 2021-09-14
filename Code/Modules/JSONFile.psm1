##### UNDER DEVELOPMENT!!!! Not for productive use !!! ####
# State: Proof of Concept 

$OBJECT_NODE_NAME = "PSCustomObject";
$ARRAY_NODE_NAME = "Object[]";
$STRING_NODE_NAME = "String";
$INT_NODE_NAME = "Int32";

$sj = '{
    "Value1" : [
        { "Value1.1" : "huhu", "value1.2" : "hehe" },
        { "Value2.1" : "TTTT" }
        ],
        "Value2" : 123
}'

$sj2 = '{
    "Value1" : [ { "Value1.1" : "Changed", "value 1.3" : "v13" } ],
    "Value3" : [ "HI", "HO" ]
}'

function Invoke-ParseObjectStructure {
    param(
        $InputObject,
        $CurrentPath
    )
    $OutValue = "";
    $DataType = $InputObject.GetType().Name;
    $CurrentPath += ":$DataType"
    switch ( $InputObject.GetType().Name ) {
       "Object[]" {
            For ( $i = 0; $i -lt $InputObject.Count; $i++ ) {
                $NewPath = "$CurrentPath/$i";
                Invoke-ParseObjectStructure -InputObject $InputObject[$i] -CurrentPath $NewPath -Elements $Elements
            }
            
        }
        "PSCustomObject" {
            ForEach ( $noteProperty in (Get-Member -InputObject $InputObject | WHERE { $_.MemberType -eq "NoteProperty"} ) ) {           
                $notePropertyName = $noteProperty.Name
                $NewPath = "$CurrentPath/$notePropertyName";
                Invoke-ParseObjectStructure -InputObject $InputObject.$notePropertyName -CurrentPath $NewPath -Elements $Elements;
            }
        } default {
          
            @{
                "Path" = $CurrentPath;
                "Value" = $InputObject
            };
        }

   }
}

function Invoke-ParseJSonStructure {
    param(
        [string]$InputObject
    )

    $object = ConvertFrom-Json $InputObject

    $Elements = Invoke-ParseObjectStructure -InputObject $object -CurrentPath "/";

    return $Elements

}
$parsed = Invoke-ParseJSonStructure -InputObject $sj


function Set-JSonNodeByJPPath {
    param(
        [string]$Path,
        [string]$Value,
        $InputObject
    )
    $Path = $Path -replace "^/", "";
    $Nodes = $Path -split "/";

    Write-Host $Path

    if ( !$InputObject ) {
        $NodeName, $NodeType = $Nodes[0] -split ":";
        Write-Host $NodeType
        $InputObject = New-JSonNode $NodeType;
    }

    $CurrentObject = $InputObject;
    $ObjectToSet = $null;




    For ( $i = 1; $i -lt $Nodes.Count; $i++ ) {
        $NodeName, $NodeType = $Nodes[$i] -split ":";
        $ObjectToSet = $CurrentObject;

        Write-Host "CurrentObject: $NodeName - $CurrentObject"
        Write-Host $CurrentObject.GetType().Name


        if ( !$CurrentObject[$NodeName] ) {
       
            Write-Host "Modifing PSCUstomObject";

            if ( $CurrentObject.GetType().Name -eq "ArrayList" ) {
                
                
                Write-Host "Modifing Object[]:";
                while ( $CurrentObject.Count -le $NodeName ) {
                    $CurrentObject.Add($null) | Out-Null
                }
                    
            }
            switch ( $NodeType ) {
                "PSCustomObject"  {
                    $CurrentObject[$NodeName] = @{};
                }
                "Object[]" {
                    $CurrentObject[$NodeName] = [System.Collections.ArrayList]@($null,$null)
                    #$CurrentObject[$NodeName] = @($null,$null)
                }
                default {
                    $CurrentObject[$NodeName] = "";
                }
            }

            Write-Host (ConvertTo-Json $CurrentObject);
            
        }
        $CurrentObject = $CurrentObject[$NodeName];
    }
    $NodeName, $NodeType = $Nodes[$i-1] -split ":";
    Write-Host "Setting Value $i - $NodeName $ObjectToSet";
    $ObjectToSet.$NodeName = $Value;
    return $InputObject
}

ForEach ( $parse in $parsed ) {
    $s1=Set-JSonNodeByJPPath -Path $parse.Path -Value $parse.Value -InputObject $s1
}

$s1=Set-JSonNodeByJPPath -Path "/:PSCustomObject/Value21:Object[]/4:Object[]/3:PSCustomObject/Value1.3:String" -Value "Reset"
$s1=Set-JSonNodeByJPPath -Path "/:PSCustomObject/Value21:Object[]/4:Object[]/2:PSCustomObject/Value1.3:String" -Value "Reset" -InputObject $s1
ConvertTo-Json $s1 -Depth 100;