<#
.SYNOPSIS
    Returns a list of all OLE DB Providers that are registered in the system
.DESCRIPTION
    Returns a List of all OLE DB Providers that are registered in the system

    Every element in the list has the following properties:
        SOURCES_NAME
        SOURCES_PARSENAME
        SOURCES_DESCRIPTION
        SOURCES_TYPE
        SOURCES_ISPARENT
        SOURCES_CLSID

    NOTE: OLE DB providers are 32-bits and 64-bits aware/specific.

.EXAMPLE
    C:\PS> Get-OledbRegistered

.EXAMPLE
    $list = Get-OledbRegistered
    $list | ?{ $_.SOURCES_DESCRIPTION.IndexOf('SQL Server') -ge 0 }
    To list all "SQL Server" providers
#>
function Get-OledbRegistered
{
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[PSObject]])]
    param ()

    Process
    {
        $list = New-Object ([System.Collections.Generic.List[PSObject]])

        foreach ($provider in [System.Data.OleDb.OleDbEnumerator]::GetRootEnumerator())
        {
            $v = New-Object PSObject        
            for ($i = 0; $i -lt $provider.FieldCount; $i++) 
            {
                Add-Member -in $v NoteProperty $provider.GetName($i) $provider.GetValue($i)
            }
            $list.Add($v)
        }
        return $list
    }
}
