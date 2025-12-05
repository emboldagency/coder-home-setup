variable "agent_id" {
  description = "The coder agent id to attach the script to"
  type        = string
}

variable "source_dir" {
  description = "Directory to seed from (default: /coder/home)"
  type        = string
  default     = "/coder/home"
}

variable "target_dir" {
  description = "Directory to seed into (default: $HOME)"
  type        = string
  default     = ""
}

variable "target_user" {
  description = "User to own the target directory (default: embold)"
  type        = string
  default     = "embold"
}
