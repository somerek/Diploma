# ---------------------------------------------------------------------------------------------------------------------
# Environments for diploma project
# ---------------------------------------------------------------------------------------------------------------------

variable "default_aws_region" {
  description = "AWS Region"
  type        = string
}


variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(any)
  default = {
    Owner      = "Roman"
    Project    = "EPAM diploma"
    Managed_by = "Managed by terraform"
    Email      = "Roman_Popov3@epam.com"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------------------------------------------------
variable "vpc_cidr_block" {
  description = "Cidr block for VPC"
  type        = string
}

variable "public_subnet_a_cidr_block" {
  description = "Cidr block for A public subnet"
  type        = string
}

variable "public_subnet_b_cidr_block" {
  description = "Cidr block for B public subnet"
  type        = string
}

variable "private_subnet_a_cidr_block" {
  description = "Cidr block for A private subnet"
  type        = string
}

variable "private_subnet_b_cidr_block" {
  description = "Cidr block for B private subnet"
  type        = string
}

# # ---------------------------------------------------------------------------------------------------------------------
# # INSTANCE
# # ---------------------------------------------------------------------------------------------------------------------
# variable "jenkins_ports" {
#   description = "List of port to open for server"
#   type        = list(any)
#   default     = ["80", "443", "8080", "50000"]
# }

variable "allow_ssh_from_ip" {
  description = "Allow ssh from IP"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# DATABASE GENERAL
# ---------------------------------------------------------------------------------------------------------------------
variable "DB_USER" {
  description = "User name for DB"
  type        = string
}

variable "DB_PASSWORD" {
  description = "User password for DB"
  type        = string
}

variable "DB_NAME" {
  description = "Database name"
  type        = string
}

variable "engine_name" {
  description = "Name of the database engine"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Version of the database to be launched"
  default     = "14.1"
  type        = string
}

variable "family" {
  description = "Family of the database"
  type        = string
  default     = "postgres14"
}

variable "port" {
  description = "Port which the database should run on"
  type        = number
  default     = 5432
}

variable "allocated_storage" {
  description = "Disk space to be allocated to the DB instance"
  type        = number
  default     = 5
}

variable "instance_class" {
  description = "Instance class to be used to run the database"
  type        = string
  default     = "db.t3.micro"
}

# ---------------------------------------------------------------------------------------------------------------------
# ELASTIC KUBERNETES SERVICE
# ---------------------------------------------------------------------------------------------------------------------

variable "k8s_name" {
  description = "Kubernetes Cluster Name"
  type        = string
  default     = "k8s"
}

variable "k8s_version" {
  description = "Kubernetes Version"
  type        = string
  default     = "1.21"
}

variable "k8s_node_type" {
  description = "Worrker node type"
  type        = string
  default     = "t3.medium"
}

variable "app_name" {
  type = string
  default = "music-page"
}

variable "app_env" {
  type    = set(string)
  default = ["dev", "prod"]
}

variable "zone_id" {
  description = "Route53 zone id"
  type        = string
}
variable "domain" {
  description = "Domain"
  type        = string
}
