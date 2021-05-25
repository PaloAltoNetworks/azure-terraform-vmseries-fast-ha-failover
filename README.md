![Support:Community](https://img.shields.io/badge/Support-Community-blue)
![License:MIT](https://img.shields.io/badge/License-MIT-blue)

[comment]: <> (![CI/CD]&#40;https://github.com/salsop/aws-terraform-vmseries-crosszone-high-availabilty-deployment/workflows/CI/CD/badge.svg&#41;)

# Palo Alto Networks - Fast Azure A/P Failover

### :exclamation: **IMPORTANT NOTE** :exclamation:

**Palo Alto Networks recommends the architectures in the Reference Architectures for most customer deployments, these can be found [here](https://www.paloaltonetworks.com/resources/reference-architectures/azure "Palo Alto Networks - Azure Reference Architectures").**

There are some use-cases where this solution may be more appropriate for your use:
- Site-to-Site IPSEC VPN Termination.
- Legacy applications that need the original Internet Client IP to function and cannot tolerate SNAT.

## Solution Overview
Standard A/P HA operates by detecting the failure of its peer using Palo Alto Networks native HA keepalives and then makes API calls to Azure in order to update any Azure Route Tables, and move any of the required Secondary IPs and Public IPs between instances. This results in a variable delay in fail-over depending on how fast the Azure API requests are processed.

The solution described here uses the native Azure Load Balancer to perform the traffic steering between the Active/Passive VM-Series nodes on fail-over. This means there are no API calls to be made, as soon as the Passive node detects a failure it promotes itself to Active, and after approximately 10 seconds the Azure Load Balancer starts steering new sessions to the newly Active node and restores network connectivity.

![Image](./docs/overview.jpeg?raw=true)
*(This diagram does not show HA2 and management interfaces and subnets to ensure that the data interfaces and flow is obvious.)*

### Configuration Overview:
- **Private Load Balancer Configuration:**
  - HA Ports enabled to allow easy path selection for all traffic leaving Azure.
  - Health check is HTTPS with the path `/php/login.php` to a management profile associated on the interfaces.
  - The passive node fails the health check resulting in all new sessions going via the Active node.
  

- **Public Load Balancer Configuration:**
  - All Public IP Rules enabled with Floating IP
  - Single IP Address is assigned by the Terraform Plan, but the diagram shows options for multiple services:
    - Public IP 1.1.1.1 - IPSEC VPN termination use-case to VM-Series `Loopback.10` interface.
    - Public IP 1.1.1.2 - Published web application use-case (DNAT to Internal IP on VM-Series, no SNAT)
  - Health check is HTTPS with the path `/php/login.php` to a management profile associated on the interfaces.
  - The passive node fails the health check resulting in all new sessions going via the Active node.


- **VM-Series Configuration:**
  - Active/Passive Configured but with no Azure Service Principal configured.
    - HA1 (not shown in diagram) is `Management` interface.
    - HA2 (not shown in diagram) is `Ethernet1/3` interface.
  - `Ethernet1/1` is `Public` zoned interface.
  - `Ethernet1/2` is `Private` zoned interface.
  - Two Virtual Routers are configured as in the Reference Architecture - Common Firewall Option, more information on this can be found [here](https://www.paloaltonetworks.com/resources/reference-architectures/azure "Palo Alto Networks - Azure Reference Architectures")
  - There is a different Public IP address applied to each VM-Series `Ethernet1/1` interface, so on failover the Public IP of any outbound traffic to the internet from internal systems will change.
  - The VM-Series instances are deployed across Azure availability zones.

## Solution Details

### Session Sync Behaviour

In this configuration we use the Azure Load Balancer to steer the traffic to the Active Node in the Active/Passive HA configuration.

While we configure the VM-Series firewalls for Session Synchronization using the Palo Alto Networks HA2 Interface connection, we need to be mindful of the way the Azure Load Balancer handles sessions.

The Azure Load Balancer has two modes for session persistence, "Hash Based", or "Source IP Affinity". You can find further documentation on these modes [here](https://docs.microsoft.com/en-us/azure/load-balancer/distribution-mode-concepts "Microsoft: Azure Load Balancer distribution modes").

In this configuration we make use of "Hash Based", meaning and packets of an existing session are delivered to the same instance in the Backend Pool regardless of the health of that instance.

In the event of the Active VM-Series failing, packets for any existing sessions will still be passed to it. However, using the "Hash Based" mode means that any new sessions will be distributed to only healthy instances. In our case this means the Newly Active VM-Series.

## Tested Scenarios

### Inbound Sessions
- Fail-over time for new sessions approx. 10-20 seconds.
- **Existing sessions need to be re-established.**

### Outbound Sessions
- Fail-over time for new sessions approx. 140 seconds due to NAT configuration.
- **Existing sessions need to be re-established.**

### IPSEC VPN Termination to Loopback Interface
- Using Frontend IP (Floating IP) and Loopback (with Frontend IP) port forwarding `UDP/500` and `UDP/4500` to VM-Series.
- Fail-over time for VPN 10-20 seconds to reestablish and allow traffic flow.

### Configuration Notes

- Username and Password:
  - Username is: `pandemo`
  - Password is: `Pal0Alto!`
- This configuration was tested with PAN-OS v10.0.5
- There is a different Public IP on each instance, these Public IPs do not get moved between instances. After fail-over you will change your Source IP for any traffic going to the Internet.

## Deploying this Configuration

### Prerequisites:

You must have the following installed and configured:
- Azure CLI
- Terraform 0.14.0 or above


### STEP 1: Create a local copy of the GitHub Repository.

Run this command:
```
git clone https://github.com/PaloAltoNetworks/azure-terraform-vmseries-fast-ha-failover
```
### STEP 2: Create bootstrap folders.
In the `bootstrap_files` folder create the empty bootstrap folders using the following commands:

```
mkdir bootstrap_files/content
```

```
mkdir bootstrap_files/plugins
```

```
mkdir bootstrap_files/software
```

### STEP 3: Change any relevant variables for the deployment.

Create a `terraform.tfvars` file or modify the `variables.tf` file as needed, this deployment will succeed with no modifications.

### STEP 4: Initialize Terraform.

Run the following command
```
terraform init
```

### STEP 5: Check the Terraform Plan

Run this command and review the output to ensure you are happy with changes that will be made:

```
terraform plan
```

### STEP 6: Apply the Terraform Plan

:exclamation: **Ensure you are happy with the changes show in the Terraform Plan before running this step.**

Run this command to apply the changes, once the plan is displayed enter `Yes` to make the changes.

```
terraform apply
```

Once the `terraform apply` has completed you will see the outputs displayed on the screen like this:
```
Apply complete! Resources: 74 added, 0 changed, 0 destroyed.

Outputs:

ingress_lb_pip = "1.1.1.1"
vmseries0_management_ip = "4.4.4.4"
vmseries1_management_ip = "5.5.5.5"
```

These outputs show:
- `ingress_lb_pip` = Public IP Address on the Public Load Balancer
- `vmseries0_management_ip` = Public IP Address on the management interface of VMSeries0.
- `vmseries1_management_ip` = Public IP Address on the management interface of VMSeries1.

### STEP 7: Synchronize the Configuration

At the end of the previous tep you will be provided some on screen output with the Public IP Addresses of the Management Interfaces.

```
ssh pandemo@4.4.4.4
```

Enter the password (`Pal0Alto`) when prompted:

```
Password:
```

If successful you will see a prompt like this:

```
Number of failed attempts since last successful login: 0

pandemo@vmseries0-vm(active)> 
```

Here run the following command to synchronize the configuration between the High-Availability pair:

```
pandemo@vmseries1-vm(active)> request high-availability sync-to-remote running-config 

Executing this command will overwrite the candidate configuration on the peer and trigger a commit on the peer. Do you want to continue? (y or n) 
```

Ensure that you are on the correct firewall, and you're happy to proceed then press `y` to continue.

You will then see the following output:

```
HA synchronization job has been queued on peer. Please check job status on peer.

pandemo@vmseries1-vm(active)> 
```

### STEP 8: Continue to apply your custom configuration.

You can now apply any other configurations you wish on the VM-Series to meet you needs.

If you are terminating IPSEC VPNs, use a Loopback Interface with the Public IP Address on for the VPN Configuration.

## Support Policy

The code and templates in the repo are released under an as-is, best-effort, support policy. These scripts should be seen as community supported and Palo Alto Networks will contribute our expertise as and when possible. We do not provide technical support or help in using or troubleshooting the components of the project through our normal support options such as Palo Alto Networks support teams, or ASC (Authorized Support Centers) partners and back line support options. The underlying product used (the VM-Series firewall) by the scripts or templates are still supported, but the support is only for the product functionality and not for help in deploying or using the template or script itself. Unless explicitly tagged, all projects or work posted in our GitHub repository (at https://github.com/PaloAltoNetworks) or sites other than our official Downloads page on https://support.paloaltonetworks.com are provided under the best effort policy.

Please raise issues in GitHub for any problems you encounter, or if you need help using this.
