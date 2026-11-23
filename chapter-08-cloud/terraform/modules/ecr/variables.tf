variable "prefix" {
  type        = string
  description = "Namespace for repository names, e.g. zero2ai-dev -> zero2ai-dev/fraud-api."
}

variable "repositories" {
  type        = list(string)
  description = "App names, one repository each."
}

variable "immutable_tags" {
  type    = bool
  default = false
}

variable "force_delete" {
  type    = bool
  default = true
}

variable "keep_images" {
  type    = number
  default = 20
}
