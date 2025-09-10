Function Get-IniContent {  
    <#  
    .Synopsis  
        Gets the content of an INI file  
          
    .Description  
        Gets the content of an INI file and returns it as a hashtable  
          
    .Notes  
        Author        : Oliver Lipkau <oliver@lipkau.net>  
        Blog        : http://oliver.lipkau.net/blog/  
        Source        : https://github.com/lipkau/PsIni 
                      http://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91 
        Version        : 1.0 - 2010/03/12 - Initial release  
                      1.1 - 2014/12/11 - Typo (Thx SLDR) 
                                         Typo (Thx Dave Stiff) 
                         1.3 - 2021/03/27 - By Hauke Goetze: Modified to ignore comments and to better mark no section areas. 
          
        #Requires -Version 2.0  
          
    .Inputs  
        System.String  
          
    .Outputs  
        System.Collections.Hashtable  
          
    .Parameter FilePath  
        Specifies the path to the input file.  
          
    .Example  
        $FileContent = Get-IniContent "C:\myinifile.ini"  
        -----------  
        Description  
        Saves the content of the c:\myinifile.ini in a hashtable called $FileContent  
      
    .Example  
        $inifilepath | $FileContent = Get-IniContent  
        -----------  
        Description  
        Gets the content of the ini file passed through the pipe into a hashtable called $FileContent  
      
    .Example  
        C:\PS>$FileContent = Get-IniContent "c:\settings.ini"  
        C:\PS>$FileContent["Section"]["Key"]  
        -----------  
        Description  
        Returns the key "Key" of the section "Section" from the C:\settings.ini file  
          
    .Link  
        Out-IniFile  
    #>  
      
    [CmdletBinding()]  
    Param(  
        [ValidateNotNullOrEmpty()]  
        [ValidateScript({Test-Path $_})]  
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
        [string]$FilePath  
    )  
      
    Begin  
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"}  
          
    Process  
    {  
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing file: $Filepath"  
              
        $ini = @{}  
        switch -regex -file $FilePath  
        {  
            "^\[(.+)\]" # Section  
            {  
                $section = $matches[1]  
                $ini[$section] = @{}  
                $CommentCount = 0  
            }   
            "^([^#;]{1}.+?)\s*=\s*(.*)" # Key  
            {  
                if (!($section))  
                {  
                    $section = "__No-Section__"  
                    $ini[$section] = @{}  
                }  
                $name,$value = $matches[1..2]  
                $ini[$section][$name] = $value  
            }  
        }  
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing file: $FilePath"  
        Return $ini  
    }  
          
    End  
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"}  
} 

Function Out-IniFile {  
    <#  
    .Synopsis  
        Write hash content to INI file  
          
    .Description  
        Write hash content to INI file  
          
    .Notes  
        Author        : Oliver Lipkau <oliver@lipkau.net>  
        Blog        : http://oliver.lipkau.net/blog/  
        Source        : https://github.com/lipkau/PsIni 
                      http://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91 
        Version        : 1.0 - 2010/03/12 - Initial release  
                      1.1 - 2012/04/19 - Bugfix/Added example to help (Thx Ingmar Verheij)  
                      1.2 - 2014/12/11 - Improved handling for missing output file (Thx SLDR)
                      1.3 - 2021/03/27 - By Hauke Goetze: Better support for no section keys. 
          
        #Requires -Version 2.0  
          
    .Inputs  
        System.String  
        System.Collections.Hashtable  
          
    .Outputs  
        System.IO.FileSystemInfo  
          
    .Parameter Append  
        Adds the output to the end of an existing file, instead of replacing the file contents.  
          
    .Parameter InputObject  
        Specifies the Hashtable to be written to the file. Enter a variable that contains the objects or type a command or expression that gets the objects.  
  
    .Parameter FilePath  
        Specifies the path to the output file.  
       
     .Parameter Encoding  
        Specifies the type of character encoding used in the file. Valid values are "Unicode", "UTF7",  
         "UTF8", "UTF32", "ASCII", "BigEndianUnicode", "Default", and "OEM". "Unicode" is the default.  
          
        "Default" uses the encoding of the system's current ANSI code page.   
          
        "OEM" uses the current original equipment manufacturer code page identifier for the operating   
        system.  
       
     .Parameter Force  
        Allows the cmdlet to overwrite an existing read-only file. Even using the Force parameter, the cmdlet cannot override security restrictions.  
          
     .Parameter PassThru  
        Passes an object representing the location to the pipeline. By default, this cmdlet does not generate any output.  
                  
    .Example  
        Out-IniFile $IniVar "C:\myinifile.ini"  
        -----------  
        Description  
        Saves the content of the $IniVar Hashtable to the INI File c:\myinifile.ini  
          
    .Example  
        $IniVar | Out-IniFile "C:\myinifile.ini" -Force  
        -----------  
        Description  
        Saves the content of the $IniVar Hashtable to the INI File c:\myinifile.ini and overwrites the file if it is already present  
          
    .Example  
        $file = Out-IniFile $IniVar "C:\myinifile.ini" -PassThru  
        -----------  
        Description  
        Saves the content of the $IniVar Hashtable to the INI File c:\myinifile.ini and saves the file into $file  
  
    .Link  
        Get-IniContent  
    #>  
      
    [CmdletBinding()]  
    Param(  
        [switch]$Append,  
          
        [ValidateSet("Unicode","UTF7","UTF8","UTF32","ASCII","BigEndianUnicode","Default","OEM")]  
        [Parameter()]  
        [string]$Encoding = "Unicode",  
 
          
        [ValidateNotNullOrEmpty()]  
        [Parameter(Mandatory=$True)]  
        [string]$FilePath,  
          
        [switch]$Force,  
          
        [ValidateNotNullOrEmpty()]  
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
        [Hashtable]$InputObject,  
          
        [switch]$Passthru  
    )  
      
    Begin  
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"}  
          
    Process  
    {  
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing to file: $Filepath"  
        if ( !(Test-Path -Path "$Filepath\..") ) {
                New-Item -Path $Filepath\.. -ItemType Directory
        }

        $NoSectionContent = "";
        $SectionContent = "";
          
        if ($append) {$outfile = Get-Item $FilePath}  
        else {$outFile = New-Item -ItemType file -Path $Filepath -Force:$Force}  
        if (!($outFile)) {Throw "Could not create File"}  
        foreach ($i in $InputObject.keys)  
        {  
            if (!($($InputObject[$i].GetType().Name) -eq "Hashtable"))  
            {  
                #No Sections  
                Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing key: $i"   
                $NoSectionContent += "$i=$($InputObject[$i])`n"
            } else {  
                #Sections  
                Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing Section: [$i]"  
                If ( $i -ne "__No-Section__" ) {
                    $SectionContent += "[$i]`n"
                }
                Foreach ($j in $($InputObject[$i].keys | Sort-Object))  
                {  
                    if ($j -match "^Comment[\d]+") {  
                        Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing comment: $j"  
                        $SectionContent += "$($InputObject[$i][$j])`n" 
                    } else {  
                        Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing key: $j" 
                        $SectionContent += "$j=$($InputObject[$i][$j])`n" 
                    }  
                      
                }  
                $SectionContent += "`n"
            }  
        }  
        Add-Content -Path $outFile -Value $NoSectionContent -Encoding $Encoding  
        Add-Content -Path $outFile -Value $SectionContent -Encoding $Encoding

        Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Writing to file: $path"  
        if ($PassThru) {Return $outFile}  
    }  
          
    End  
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"}  
}


function Invoke-__NoSection__CleanUp{
    param(
        [ValidateNotNullOrEmpty()]  
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
        [Hashtable]$InputObject
    )

    if ( $InputObject["__No-Section__"] ) {
        ForEach ( $key in $InputObject["__No-Section__"].Keys ) {
            $InputObject[$key] = $InputObject["__No-Section__"][$Key];

        }

        $InputObject.Remove("__No-Section__");
    }

    return $InputObject;
}

function Invoke-IniRemediation {
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

    $new_config = $null;
    $compliance = "Compliant"
    $fileWasCreated = $false;

    If ( Test-Path -Path $FilePath ) {
        $current_config = Get-IniContent -FilePath $FilePath;
        $encoding = Get-FileEncoding -Path $FilePath;

        ForEach ( $rule in $rules ) {
            if ( $rule.Operation -ne "Delete" ) {
                $sectionExists = $false;

                if ( !($current_config[$rule["Section"]]) ) {
                    if ( ($rule.Operation -eq "Create") -or ($rule.Operation -eq "Replace") ) {
                        $current_config[$rule["Section"]] = @{};
                        $sectionExists = $true;
                    }
                } else {
                    $sectionExists = $true;
                }
                if ( $sectionExists -eq $true ) {
                    if ( $current_config[$rule["Section"]][$rule["Key"]] -ne $rule["Value"] ) {
                        $compliance = "Non-Compliant: Section: " + $rule["Section"] + " Key: " + $rule["Key"] + " is not '" + $rule["Value"] + "' but '"+ $current_config[$rule["Section"]][$rule["Key"]] + "'";

                        if ( (!$current_config[$rule["Section"]][$rule["Key"]]) -and ($rule.Operation -eq "Create") ) {
                            $current_config[$rule["Section"]][$rule["Key"]] = $rule["Value"];
                        }

                    
                        if ( ($rule.Operation -eq "Update") -or ($rule.Operation -eq "Replace") ) {
                            $current_config[$rule["Section"]][$rule["Key"]] = $rule["Value"];
                        }
                    }
                } else {
                    $compliance = "Non-Compliant: Section " + $rule["Section"] + " does not exist and is not beeing created.";
                }
            } else {
                if ( $current_config[$rule["Section"]] ) {
                    if ( $current_config[$rule["Section"]][$rule["Key"]] ) {
                        $current_config[$rule["Section"]].Remove($rule["Key"]);
                    }
                }
            }
        
        }

        $new_config = $current_config;
    }
    if ( !(Test-Path -Path $FilePath) -or ( ( $compliance -ne "Compliant" ) -and ( $Operation -eq "replace" ) ) ) {
        $compliance = "Non-Compliant: File needs to be (re-)created";
        if ( $action -eq "Remediate" ) {
###### Build new File #######
            $new_config = @{}
            ForEach ( $rule in $rules ) {
                if ( $rule.Operation -eq "Replace" -or $rule.Operation -eq "Create" ) {
                    if ( !($new_config[$rule["Section"]]) ) {
                        $new_config[$rule["Section"]] = @{};
                    }
                    $new_config[$rule["Section"]][$rule["Key"]] = $rule["Value"];
                }
            }
            $fileWasCreated = $true;  
        }
    }
    if ( $action -eq "Remediate" -and $compliance -ne "Compliant" ) {
        $new_config = Invoke-__NoSection__CleanUp -InputObject $new_config;
        if ( ( $fileWasCreate -eq $false ) -or ( $operation -eq "create") -or ( $Operation -eq "replace" ) ) {
            $new_config | Out-IniFile -FilePath $FilePath -Force -Encoding $Encoding;
        }
    }

    $compliance;
}