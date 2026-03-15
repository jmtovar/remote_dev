# Ephemeral Cloud Dev Environment

A minimal, reproducible remote dev setup using AWS + Claude Code.  
Spin up a fresh instance in ~2 minutes. Work. Destroy. Pay nothing while idle.

---

## Directory Structure

```
ephemeral-dev/
├── session.sh              ← daily driver (run on YOUR local machine)
├── scripts/
│   └── bootstrap.sh        ← installs tools on the remote instance
└── terraform/
    ├── main.tf             ← AWS infrastructure definition
    └── terraform.tfvars    ← your secrets (DO NOT commit)
```

---

## Prerequisites (on your local machine)

- [Terraform](https://developer.hashicorp.com/terraform/install) or [OpenTofu](https://opentofu.org/docs/intro/install/)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured (`aws configure`)
- An SSH key at `~/.ssh/id_ed25519` (`ssh-keygen -t ed25519`)
- An [Anthropic API key](https://console.anthropic.com)

---

## One-time Setup

```bash
# 1. Clone this repo to your local machine
git clone git@github.com:jmtovar/remote_dev.git
cd remote_dev

# 2. Fill in your values
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
vim terraform/terraform.tfvars

# 3. Make scripts executable
chmod +x session.sh scripts/bootstrap.sh

# 4. Recommended: push bootstrap.sh to a public dotfiles repo
#    so cloud-init can pull it automatically on boot
```

---

## Daily Workflow

### Start a session
```bash
./session.sh up
```
This provisions an EC2 spot instance, waits for SSH, and drops you in.  
Cloud-init runs `bootstrap.sh` automatically in the background on first boot.

### On the remote instance
```bash
# Authenticate GitHub CLI (once per instance)
gh auth login

# Clone your project
git clone git@github.com:you/myproject.git
cd myproject

# Start Claude Code
claude
```

### Working with Claude Code
Claude Code understands your whole codebase. Just talk to it:
```
> fix the bug in auth.py where tokens expire too early
> add unit tests for the payment module
> commit everything with a good message and push
> create a github issue for the pagination bug we discussed
```

### End a session — commit first!
```bash
# On the remote instance:
git add -A && git commit -m "wip: end of session" && git push

# Then on your local machine:
./session.sh down   # destroys the instance
```

---

## Cost Estimate (AWS eu-west-1)

| Resource          | Cost                        |
|-------------------|-----------------------------|
| t3.medium spot    | ~$0.010–0.015/hr            |
| 20 GB gp3 EBS     | ~$0.002/hr (deleted on destroy) |
| Data transfer     | negligible for dev          |
| **4hr session**   | **~$0.05–0.07 total**       |

A full working week of 4-hour sessions ≈ **$0.25–0.35**.

---

## Security Notes

- SSH is locked to your IP only (checked at `terraform apply` time)
- Your API key lives in `terraform.tfvars` — add it to `.gitignore`
- The instance has no inbound ports other than SSH 22
- `delete_on_termination = true` means no data lingers after destroy

---

## .gitignore

```
terraform/.terraform/
terraform/*.tfstate
terraform/*.tfstate.backup
terraform/terraform.tfvars    ← secrets here
.env
```
