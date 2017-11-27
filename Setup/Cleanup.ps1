[CmdletBinding()]
param(
)
$EmailLambdaStack = 'EmailLambdaStack'
$LinuxInstanceStack = 'LinuxInstanceStack'
$WindowsInstanceStack = 'WindowsInstanceStack'
$SNSStack = 'SNSStack'
$AsgStack = 'AsgStack'
$InstallApacheDocName = 'Nana-InstallApache'
$BounceHostName = 'Nana-BounceHostRunbook'
$CreateManagedInstanceDoc = 'Nana-CreateManagedInstanceLinux'
$CreateManagedInstanceWithApprovalDoc = 'Nana-CreateManagedInstanceWithApproval'

$AllStacks = @($EmailLambdaStack, $LinuxInstanceStack, $WindowsInstanceStack, $SNSStack, $AsgStack)
$AllDocs = @($InstallApacheDocName, $BounceHostName, $CreateManagedInstanceDoc, $CreateManagedInstanceWithApprovalDoc)
function Wait-Stack
{
	param(
		[string]
		$StackName
	)
	while(Test-CFNStack -StackName $StackName){
		Write-Verbose "Waiting for Stack $StackName to be deleted"
		Start-Sleep -Seconds 3
	}
}
$AllStacks | % {
	if (Test-CFNStack -StackName $_){
		Remove-CFNStack -StackName $_ -Force
	}
}

$AllStacks | % {
	Wait-Stack -StackName $_
}

$AllDocs | % {
	Remove-SSMDocument -Name $_ -Force
}
