[CmdletBinding()]
param(
)
$EmailLambdaStack = 'EmailLambdaStack'
$LinuxInstanceStack = 'LinuxInstanceStack'
$InstallApacheDocName = 'Nana-InstallApache'
$BounceHostName = 'Nana-BounceHostRunbook'

$StackName, $EmailLambdaStack, $LinuxInstanceStack | % {
	if (Test-CFNStack -StackName $_){
		Remove-CFNStack -StackName $_ -Force
	}
}

Remove-SSMDocument -Name $InstallApacheDocName -Force
Remove-SSMDocument -Name $BounceHostName -Force