function Write-LogFile {
<#
.SYNOPSIS
    Writes an entry to the log file.
.DESCRIPTION
    Writes an entry to the PolicyApplicator Log file in the temporary folder.
.INPUTS
    string
.PARAMETER InputObject
    The message that should be written to the log file.
.OUTPUTS
    bool
.NOTES
    Created by Hauke Goetze
.LINK
    https://policyapplicator.weatherlights.com
#>
    param(
        [Parameter(Mandatory=$True)][string]$InputObject
    );

    $LogDir = "$env:temp\$env:computername-PolicyApplicator.log"
    $time = Get-Date -Format "HH:mm:ss";
    $date = Get-Date -Format "MM-dd-yyyy";
    $logmessage = "<![LOG[$InputObject]LOG]!><time=`"$time.0000000`" date=`"$date`" component=`"PolicyApplicator`" context=`"`" type=`"`" thread=`"`" file=`"`">";
    Out-File -FilePath $LogDir -Append -InputObject $logmessage -Encoding UTF8;
    $size=(Get-Item $LogDir).length

    if ( $size -gt 5120000 ) {
        Move-Item -Path $LogDir -Destination "$LogDir.bak"
    }
    
}

function Out-RemediatedFile {
<#
.SYNOPSIS
    Writes content to a file.
.DESCRIPTION
    Writes a given string content to a file.
.INPUTS
    string
.PARAMETER InputObject
    The string that should be written to the file.
.PARAMETER FilePath
    The path to the file where the content should be written.
.PARAMETER CreateVerbose
    If the file does not exist should the file and the residing folders be created.
.PARAMETER Encoding
    The encoding of the file.
.NOTES
    Created by Hauke Goetze
.LINK
    https://policyapplicator.weatherlights.com
#>
param(
        [ValidateNotNullOrEmpty()]  
        [ValidateScript({Test-Path $_})]  
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
        [string]$FilePath,

        [switch]$CreateVerbose,

        [ValidateSet("Unicode","UTF7","UTF8","UTF32","ASCII","BigEndianUnicode","Default","OEM")]  
        [Parameter()]  
        [string]$Encoding = "Unicode",

        [ValidateNotNullOrEmpty()][Parameter(Mandatory=$True)]$InputObject
);
        if ( !(Test-Path -Path "$FilePath\..") ) {
            if ( $CreateVerbose ) {
                New-Item -Path $FilePath\.. -ItemType Directory
            }
        }
        if ( Test-Path -Path "$FilePath\.." ) {
            Out-File -FilePath $FilePath -Encoding $encoding -InputObject $InputObject;
        }
}

# from https://gist.github.com/zommarin/1480974
function Get-FileEncoding($Path) {
<#
.SYNOPSIS
    Gets the file encoding of a file.
.DESCRIPTION
    Gets the file encoding of a file.
.OUTPUTS
    string
.PARAMETER Path
    Path to the file from that you want to get the encoding.
.LINK
    https://gist.github.com/zommarin/1480974
#>
    $bytes = [byte[]](Get-Content $Path -Encoding byte -ReadCount 4 -TotalCount 4)

    if(!$bytes) { return 'utf8' }

    switch -regex ('{0:x2}{1:x2}{2:x2}{3:x2}' -f $bytes[0],$bytes[1],$bytes[2],$bytes[3]) {
        '^efbbbf'   { return 'utf8' }
        '^2b2f76'   { return 'utf7' }
        '^fffe'     { return 'unicode' }
        '^feff'     { return 'bigendianunicode' }
        '^0000feff' { return 'utf32' }
        default     { return 'ascii' }
    }
}

function ConvertTo-XmlCompatibleString {
<#
.SYNOPSIS
    Makes a string XML compatible.
.DESCRIPTION
    Makes a string XML compatible.
.OUTPUTS
    string
.PARAMETER InputObject
    The string you want to convert.
.LINK
    https://policyapplicator.weatherlights.com
#>
    param (
        [string]$InputObject,
        [switch]$IgnoreQuotes
    );

    $OutObject = $InputObject -replace "&", "&amp;" -replace "<", "&lt;" -replace ">", "&gt;" -replace "`'", "&apos;";
    if ( !$IgnoreQuotes ) {
        $OutObject = $OutObject -replace "`'", "&quot;"
    }

    return $OutObject;

}