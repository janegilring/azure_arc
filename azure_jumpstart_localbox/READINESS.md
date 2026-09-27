# Pre-Arc readiness lab

This branch adds the opt-in Bicep parameter `pauseBeforeArcRegistration` (default
`false`). Existing deployments are unchanged unless the parameter is enabled.
Use the resource-group entry point `bicep/main.bicep`.
The existing `main.azd.bicep` entry point is not supported by this rehearsal:
it already has missing `resourceTags` arguments and obsolete service-principal
arguments that prevent compilation. This branch does not repair that unrelated
entry point.

Set `githubAccount=janegilring` and `githubBranch` to the **same commit** used to
download the Bicep modules. Set `pauseBeforeArcRegistration=true`,
`autoDeployClusterResource=false`, and `autoUpgradeClusterResource=false`.
Disabling `autoDeployClusterResource` alone does **not** prevent node registration.

The new pause occurs after nested VMs, networking, the router, domain controller,
and Azure Edge bootstrap are prepared, but **before** `Set-AzLocalDeployPrereqs`.
That SDK helper combines AD deployment-object creation and
`Invoke-AzStackHciArcInitialization`, so neither runs while paused.
ARM template generation, cluster validation/deployment, and post-deployment tests
are also skipped. No Azure Local cluster, resource bridge, or AKS deployment is
expected at this point. The underlying image already contains Arc components;
an installed agent is not the same as an Arc-registered machine.

## Verify the pause

- On `LocalBox-Client`, inspect `C:\LocalBox\Logs\New-LocalBoxCluster.log` and
  `C:\LocalBox\PausedBeforeArcRegistration.txt`.
- The resource group/VM progress tag should be `PausedBeforeArcRegistration`,
  not `Completed`. ARM success alone does not establish nested readiness.
- Verify both `AzLHOST1` and `AzLHOST2` are running in Hyper-V.
- Verify neither name exists as a `Microsoft.HybridCompute/machines` resource
  in the registration resource group, and check local agent state on each node.
- The setup logon task is removed after the build returns. Both build entry
  points guard against rerunning once the pause marker exists.

## Readiness and continuation

Follow the [Environment Checker documentation](https://learn.microsoft.com/en-us/azure/azure-local/manage/use-environment-checker).
Run it in elevated Windows PowerShell on the nested nodes or a suitable Windows
staging machine, **not** in a Linux management container. Prepare the AD deployment
OU/user separately before the AD validator. Retain reports and remove the
standalone checker from every Azure Local node before deployment.

Do **not** restart the provisioning scripts, remove the marker to rebuild, or run
`Set-AzLocalDeployPrereqs` to continue a private-path lab: that helper registers
without the private-path proxy and Arc gateway arguments. Instead follow
[private-path registration](https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-with-azure-arc-gateway-private-path)
on each node, then explicitly validate/deploy through the supported workflow.
Leave automatic deployment disabled.

The integrated [Statkraft lab runbook](https://github.com/janegilring/statkraft)
provides the launcher, devcontainer, and Firewall/Arc gateway infrastructure.
This nested lab rehearses the procedure; it does not certify physical hardware,
production networking, or ExpressRoute/VPN connectivity.
