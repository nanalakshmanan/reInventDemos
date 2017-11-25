[CmdletBinding()]
param(
)

$RoleName = 'SendMailLambdaRole'
$EmailLambdaStack = 'EmailLambdaStack'
$InstanceProfileName = 'NanaSSM'
$KeyPairName = 'NanasTestKeyPair'
$LinuxInstanceStack = 'LinuxInstanceStack'
$LinuxAmiId = 'ami-55ef662f'
$VpcId = 'vpc-9920dce0'
$InstallApacheDocName = 'Nana-InstallApache'
$BounceHostName = 'Nana-BounceHostRunbook'
$LambdaFunctionName = 'SendEmailToManager'
function Get-Parameter
{
	param(
		[Parameter(Position=0)]
		[string]
		$Key,

		[Parameter(Position=1)]
		[string]
		$Value
	)
	$Param = New-Object Amazon.CloudFormation.Model.Parameter
	$Param.ParameterKey = $Key
	$Param.ParameterValue = $Value
	
	return $Param
}

# create the cloud formation stacks
$contents = Get-Content ./CloudFormationTemplates/SendMailLambda.yml -Raw
$Role = Get-Parameter 'RoleName' $RoleName
$LambdaFunction = Get-Parameter 'FunctionName' $LambdaFunctionName

New-CFNStack -StackName $EmailLambdaStack -TemplateBody $contents -Parameter @($Role, $LambdaFunction) -Capability CAPABILITY_NAMED_IAM

$InstanceProfile = Get-Parameter 'InstanceProfileName' $InstanceProfileName
$KeyPair = Get-Parameter 'KeyPairName' $KeyPairName
$AmiId = Get-Parameter 'AmiId' $LinuxAmiId
$Vpc = Get-Parameter 'VpcId' $VpcId

$contents = Get-Content ./CloudFormationTemplates/LinuxInstances.yml -Raw 
New-CFNStack -StackName $LinuxInstanceStack -TemplateBody $contents -Parameter @($InstanceProfile, $KeyPair, $AmiId, $Vpc)

# wait for the stack creation to complete
$Status = (Get-CFNStack -StackName $EmailLambdaStack).StackStatus

while ($Status -ne 'CREATE_COMPLETE'){
	Write-Verbose "Waiting for stack creation to complete  $EmailLambdaStack"
	Start-Sleep -Seconds 5
	$Status = (Get-CFNStack -StackName $EmailLambdaStack).StackStatus
}

$Status = (Get-CFNStack -StackName $LinuxInstanceStack).StackStatus

while ($Status -ne 'CREATE_COMPLETE'){
	Write-Verbose "Waiting for stack creation to complete  $LinuxInstanceStack"
	Start-Sleep -Seconds 5
	$Status = (Get-CFNStack -StackName $LinuxInstanceStack).StackStatus
}

$contents = Get-Content ../SSMDocuments/Nana-InstallApache.json -Raw
New-SSMDocument -Content $contents -DocumentType Command -Name $InstallApacheDocName

$contents = Get-Content ../SSMDocuments/Nana-BounceHostRunbook.json -Raw
New-SSMDocument -Content $contents -DocumentType Automation -Name $BounceHostName