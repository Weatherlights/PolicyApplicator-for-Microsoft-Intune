
$ReportObj = @{};


function Set-Overallcompliance {
    param (
        [string]$OverallCompliance
    )

    Set-ReportSetting -name "OverallCompliance" -value $OverallCompliance
}


function Set-ReportSetting {
    param(
        [string]$name,
        [string]$value
    )

    $ReportObj.$Name = $value;
}


function Set-IniReportSetting {
    param(
        [string]$section,
        [string]$key,
        [string]$value
    )



}