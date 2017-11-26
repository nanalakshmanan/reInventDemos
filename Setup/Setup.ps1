[CmdletBinding()]
param(
)

$RoleName = 'SendMailLambdaRole'
$EmailLambdaStack = 'EmailLambdaStack'
$InstanceProfileName = 'NanaSSM'
$AsgInstanceProfileName = 'HRAppAsgRole'
$KeyPairName = 'NanasTestKeyPair'
$LinuxInstanceStack = 'LinuxInstanceStack'
$WindowsInstanceStack = 'WindowsInstanceStack'
$AsgStack = 'AsgStack'
$LinuxAmiId = 'ami-55ef662f'
$WindowsAmidId = 'ami-e3bb7399'
$VpcId = 'vpc-9920dce0'
$InstallApacheDocName = 'Nana-InstallApache'
$BounceHostName = 'Nana-BounceHostRunbook'
$CreateManagedInstanceDoc = 'Nana-CreateManagedInstanceLinux'
$CreateManagedInstanceWithApprovalDoc = 'Nana-CreateManagedInstanceWithApproval'

$LambdaFunctionName = 'SendEmailToManager'
$SNSStack = 'SNSStack'
$AllStacks = @($EmailLambdaStack, $LinuxInstanceStack, $WindowsInstanceStack, $SNSStack, $AsgStack)
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

function Wait-Stack
{
	param(
		[string]
		$StackName
	)
	$Status = (Get-CFNStack -StackName $StackName).StackStatus
	
	while ($Status -ne 'CREATE_COMPLETE'){
		Write-Verbose "Waiting for stack creation to complete  $StackName"
		Start-Sleep -Seconds 5
		$Status = (Get-CFNStack -StackName $StackName).StackStatus
	}
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

$InstanceProfile = Get-Parameter 'InstanceProfileName' $InstanceProfileName
$KeyPair = Get-Parameter 'KeyPairName' $KeyPairName
$AmiId = Get-Parameter 'AmiId' $WindowsAmidId
$Vpc = Get-Parameter 'VpcId' $VpcId

$contents = Get-Content ./CloudFormationTemplates/WindowsInstances.yml -Raw 
New-CFNStack -StackName $WindowsInstanceStack -TemplateBody $contents -Parameter @($InstanceProfile, $KeyPair, $AmiId, $Vpc)

$InstanceProfile = Get-Parameter 'InstanceProfileName' $AsgInstanceProfileName
$contents = Get-Content ./CloudFormationTemplates/AutoScalingGroup.yml -Raw
New-CFNStack -StackName $AsgStack -TemplateBody $contents -Parameter @($InstanceProfile, $AmiId, $KeyPair, $Vpc)

$contents = Get-Content ./CloudFormationTemplates/SNSTopic.yml -Raw
New-CFNStack -StackName $SNSStack -TemplateBody $contents


# wait for the stack creation to complete
$AllStacks | %{
	Wait-Stack -StackName $_
}

$contents = Get-Content ../SSMDocuments/Nana-InstallApache.json -Raw
New-SSMDocument -Content $contents -DocumentType Command -Name $InstallApacheDocName

$contents = Get-Content ../SSMDocuments/Nana-BounceHostRunbook.json -Raw
New-SSMDocument -Content $contents -DocumentType Automation -Name $BounceHostName

$contents = Get-Content ../SSMDocuments/Nana-CreateManagedInstanceLinux.json -Raw
New-SSMDocument -Content $contents -DocumentType Automation -Name $CreateManagedInstanceDoc

$contents = Get-Content ../SSMDocuments/Nana-CreateManagedInstanceWithApproval.json -Raw
New-SSMDocument -Content $contents -DocumentType Automation -Name $CreateManagedInstanceWithApprovalDoc
function Install-Apache
{
	[CmdletBinding()]
	param(
		[string[]]
		$InstanceIds
	)
	$Commands = @(
		"sudo yum -y update ",
		"sudo yum -y install httpd",
		"sudo /etc/init.d/httpd start"
	)	
	Send-SSMCommand -Comment 'Install apache' -DocumentName 'AWS-RunShellScript' -InstanceId $InstanceIds -MaxConcurrency 5 -MaxError 1 -Parameter @{commands =$Commands}
}

$ids = (Get-CFNStack -StackName 'LinuxInstanceStack').Outputs.OutputValue
$ids = $ids.Split(",")
Install-Apache -InstanceIds $ids