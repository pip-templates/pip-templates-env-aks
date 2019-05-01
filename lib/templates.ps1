function ConvertFrom-EnvTemplate
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Template,
        [Parameter(Mandatory=$false, Position=1)]
        [hashtable] $Params1 = @{},
        [Parameter(Mandatory=$false, Position=2)]
        [hashtable] $Params2 = @{}
    )

    $params = @{}
    foreach ($key in $Params1.Keys) {
        $params[$key] = $Params1[$key]
    }
    foreach ($key in $Params2.Keys) {
        $params[$key] = $Params2[$key]
    }

    $beginTag = [regex]::escape("<%=")
    $endTag = [regex]::escape("%>")
    $output = ""

    $Template = $Template -replace [environment]::newline, "`r"

    while ($Template -match "(?<pre>.*?)$beginTag(?<key>.*?)$endTag(?<post>.*)") {
        $Template = $matches.post
        $key = $matches.key.Trim()
        $value = $params[$key]
        $output += $matches.pre + $value
    }

    $output += $Template
    $output = $output -replace "`r", [environment]::newline 
    Write-Output $output
}

function Build-EnvTemplate
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $InputPath,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $OutputPath,
        [Parameter(Mandatory=$false, Position=2)]
        [hashtable] $Params1 = @{},
        [Parameter(Mandatory=$false, Position=3)]
        [hashtable] $Params2 = @{}
    )

    $template = Get-Content -Path $InputPath | Out-String
    $value = ConvertFrom-EnvTemplate -Template $template -Params1 $Params1 -Params2 $Params2
    Set-Content -Path $OutputPath -Value $value
}
