[CmdletBinding()]
param(
)
$EmailLambdaStack = 'EmailLambdaStack'
$LinuxInstanceStack = 'LinuxInstanceStack'
$WindowsInstanceStack = 'WindowsInstanceStack'
$InstallApacheDocName = 'Nana-InstallApache'
$BounceHostName = 'Nana-BounceHostRunbook'
$SNSStack = 'SNSStack'

$AllStacks = @($EmailLambdaStack, $LinuxInstanceStack, $WindowsInstanceStack, $SNSStack)
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

Remove-SSMDocument -Name $InstallApacheDocName -Force
Remove-SSMDocument -Name $BounceHostName -Force