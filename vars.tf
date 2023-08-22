variable "num_workers" {
  type        = number
  description = "Number of worker nodes to create"
  default     = 3
}

variable "region" {
  type        = string
  description = "Cluster region"
  default     = "eu-central"
}

variable "worker_size" {
  type        = string
  description = "Worker linodes size"
  default     = "g6-standard-2"
}

variable "authorized_keys" {
  type        = list(string)
  description = "List of ssh public keys that will be added to each server"
}
