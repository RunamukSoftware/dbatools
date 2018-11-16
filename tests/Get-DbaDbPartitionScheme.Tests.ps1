$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $paramCount = 5
        $defaultParamCount = 11
        [object[]]$params = (Get-ChildItem function:\Get-DbaDbPartitionScheme).Parameters.Keys
        $knownParameters = 'SqlInstance', 'SqlCredential', 'Database', 'ExcludeDatabase', 'EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $paramCount
        }
        It "Should only contain $paramCount parameters" {
            $params.Count - $defaultParamCount | Should Be $paramCount
        }
    }
}

Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        $tempguid = [guid]::newguid();
        $PFName = "dbatoolssci_$($tempguid.guid)"
        $PFScheme = "dbatoolssci_PFScheme"

        $CreateTestPartitionScheme = @"
CREATE PARTITION FUNCTION [$PFName] (int)  AS RANGE LEFT FOR VALUES (1, 100, 1000, 10000, 100000);
GO
CREATE PARTITION SCHEME $PFScheme AS PARTITION [$PFName] ALL TO ( [PRIMARY] );
"@

        Invoke-DbaQuery -SqlInstance $script:instance2 -Query $CreateTestPartitionScheme -Database master
    }
    AfterAll {
        $DropTestPartitionScheme = @"
DROP PARTITION SCHEME [$PFScheme];
GO
DROP PARTITION FUNCTION [$PFName];
"@
        Invoke-DbaQuery -SqlInstance $script:instance2 -Query $DropTestPartitionScheme -Database master
    }

    Context "Partition Functions are correctly located" {
        $results1 = Get-DbaDbPartitionScheme -SqlInstance $script:instance2 -Database master | Select-Object *
        $results2 = Get-DbaDbPartitionScheme -SqlInstance $script:instance2

        It "Should execute and return results" {
            $results2 | Should -Not -Be $null
        }

        It "Should execute against Master and return results" {
            $results1 | Should -Not -Be $null
        }

        It "Should have matching name $PFScheme" {
            $results1.name | Should -Be $PFScheme
        }

        It "Should have PartitionFunction of $PFName " {
            $results1.PartitionFunction | Should -Be $PFName
        }

        It "Should have FileGroups of [Primary]" {
            $results1.FileGroups | Should -Be @('PRIMARY', 'PRIMARY', 'PRIMARY', 'PRIMARY', 'PRIMARY', 'PRIMARY')
        }

        It "Should not Throw an Error" {
            {Get-DbaDbPartitionScheme -SqlInstance $script:instance2 -ExcludeDatabase master } | Should -not -Throw
        }
    }
}