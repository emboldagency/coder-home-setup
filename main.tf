terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
  }
}

resource "coder_script" "gem_setup" {
  agent_id           = var.agent_id
  script             = templatefile("${path.module}/run.sh", {
    SOURCE_DIR = var.source_dir
    TARGET_DIR = var.target_dir
  })
  display_name       = "Home Seeding and Gem Setup"
  icon               = "/emojis/1f3e0.png"
  run_on_start       = true
  start_blocks_login = true
}
