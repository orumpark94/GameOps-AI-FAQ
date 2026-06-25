[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("all", "chatbot-api", "chatbot-web")]
    [string]$Service,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ImageTag,

    [string]$Namespace = "gameops-chatbot-dev",

    [string]$InfrastructureDirectory = (
        Join-Path $PSScriptRoot "..\infra\terraform\envs\dev\infrastructure"
    )
)

$ErrorActionPreference = "Stop"

function Assert-Command {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command was not found in PATH: $Name"
    }
}

function Get-TerraformOutput {
    param([Parameter(Mandatory = $true)][string]$Name)

    $value = terraform "-chdir=$InfrastructureDirectory" output -raw $Name

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($value)) {
        throw "Unable to read Terraform output: $Name"
    }

    return $value.Trim()
}

function Deploy-Service {
    param(
        [Parameter(Mandatory = $true)][string]$Deployment,
        [Parameter(Mandatory = $true)][string]$Container,
        [Parameter(Mandatory = $true)][string]$RepositoryUrl
    )

    $image = "${RepositoryUrl}:${ImageTag}"
    $repositoryName = $RepositoryUrl.Split("/", 2)[1]

    aws ecr describe-images `
        --region $region `
        --repository-name $repositoryName `
        --image-ids "imageTag=$ImageTag" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "ECR image does not exist: $image"
    }

    Write-Host "Deploying $Deployment with image $image"

    kubectl set image "deployment/$Deployment" "$Container=$image" -n $Namespace
    if ($LASTEXITCODE -ne 0) {
        throw "kubectl set image failed for $Deployment"
    }

    kubectl rollout status "deployment/$Deployment" -n $Namespace --timeout=300s
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Rollout failed. Current deployment image:"
        kubectl get "deployment/$Deployment" -n $Namespace `
            -o "jsonpath={.spec.template.spec.containers[0].image}"
        throw "Rollout failed for $Deployment"
    }
}

Assert-Command "terraform"
Assert-Command "aws"
Assert-Command "kubectl"

$resolvedInfrastructureDirectory = (
    Resolve-Path -LiteralPath $InfrastructureDirectory -ErrorAction Stop
).Path
$InfrastructureDirectory = $resolvedInfrastructureDirectory

$region = Get-TerraformOutput "aws_region"
$clusterName = Get-TerraformOutput "eks_cluster_name"
$repositoryUrlsJson = terraform "-chdir=$InfrastructureDirectory" output -json ecr_repository_urls

if ($LASTEXITCODE -ne 0) {
    throw "Unable to read ECR repository URLs from Terraform output."
}

$repositoryUrls = $repositoryUrlsJson | ConvertFrom-Json

aws sts get-caller-identity | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "AWS credentials are not available. Run aws login or configure an AWS profile."
}

aws eks update-kubeconfig --region $region --name $clusterName | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to update kubeconfig for EKS cluster $clusterName"
}

kubectl get namespace $Namespace | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Kubernetes namespace does not exist: $Namespace"
}

if ($Service -in @("all", "chatbot-api")) {
    Deploy-Service `
        -Deployment "chatbot-api" `
        -Container "chatbot-api" `
        -RepositoryUrl $repositoryUrls."gameops-ai-faq-chatbot-api"
}

if ($Service -in @("all", "chatbot-web")) {
    Deploy-Service `
        -Deployment "chatbot-web" `
        -Container "chatbot-web" `
        -RepositoryUrl $repositoryUrls."gameops-ai-faq-chatbot-web"
}

Write-Host "Deployment completed."
