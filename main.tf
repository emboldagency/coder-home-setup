terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
  }
}

resource "coder_script" "gem_setup" {
  agent_id           = var.agent_id
  display_name       = "Home Seeding and Gem Setup"
  icon               = "https://api.embold.net/icons/?name=fas-house.svg&color=009dff"
  run_on_start       = true
  start_blocks_login = true
  script = templatefile("${path.module}/run.sh", {
    SOURCE_DIR  = var.source_dir
    TARGET_DIR  = var.target_dir
    TARGET_USER = var.target_user
  })
}
