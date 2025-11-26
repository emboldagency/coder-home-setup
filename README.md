# coder-home-setup

Coder module that seeds files from `/coder/home` (the persistent coder area) into the user's home on workspace start. In addition, it will migrate legacy Ruby gems from `/coder/home` to the home directory.

## Inputs

- `agent_id` (string) - The coder agent id to attach the script to.
- `count` (number) - How many agent scripts to create (usually workspace start_count).
- `source_dir` (string, optional) - Directory to seed from (default: `/coder/home`).
- `target_dir` (string, optional) - Directory to seed into (default: `$HOME`).

The module uses Terraform's `templatefile` to inject `source_dir` and `target_dir` into the seeding script at render time. This allows you to customize where files are copied from and to, matching the pattern used in other embold modules.

## Usage

```terraform
module "home_setup" {
  source     = "git::https://github.com/emboldagency/coder-home-setup.git?ref=v1.0.0"
  count      = data.coder_workspace.me.start_count
  agent_id   = coder_agent.example.id
  source_dir = "/coder/home"      # Optional, override as needed
  target_dir = "/home/coder"      # Optional, override as needed
}
```

The module will create a `coder_script` that runs at workspace start and performs safe, idempotent migration/seeding of gems and user files. The `source_dir` and `target_dir` variables are injected into the script using Terraform's `templatefile` function.
