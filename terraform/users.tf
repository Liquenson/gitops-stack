locals {
  devops_users = [
    "dev-kevin",
    "dev-wesley",
    "dev-ruben",
    "dev-pelegrino",
    "dev-aisa",
    "dev-ismael",
    "dev-fermme",
    "liquenson-cli"
  ]
  developer_users = [
    "dev-yolanda",
    "dev-marcus",
    "dev-elena",
    "dev-william"
  ]
  security_users = [
    "sec-maria",
    "sec-john",
    "sec-anna"
  ]
  monitoring_users = [
    "ops-pedro",
    "ops-sofia",
    "ops-james"
  ]
  data_users = [
    "data-luis",
    "data-nina",
    "data-alex"
  ]
}

# Usuarios devops-team
resource "aws_iam_user" "devops" {
  for_each = toset(local.devops_users)
  name     = each.value
  tags = {
    team    = "devops"
    project = "gitops-stack"
  }
}

# Usuarios developers
resource "aws_iam_user" "developers" {
  for_each = toset(local.developer_users)
  name     = each.value
  tags = {
    team    = "developers"
    project = "gitops-stack"
  }
}

# Usuarios security-team
resource "aws_iam_user" "security" {
  for_each = toset(local.security_users)
  name     = each.value
  tags = {
    team    = "security"
    project = "gitops-stack"
  }
}

# Usuarios monitoring-team
resource "aws_iam_user" "monitoring" {
  for_each = toset(local.monitoring_users)
  name     = each.value
  tags = {
    team    = "monitoring"
    project = "gitops-stack"
  }
}

# Usuarios data-team
resource "aws_iam_user" "data" {
  for_each = toset(local.data_users)
  name     = each.value
  tags = {
    team    = "data"
    project = "gitops-stack"
  }
}

# Grupos IAM
resource "aws_iam_group" "devops" {
  name = "devops-team"
}
resource "aws_iam_group" "developers" {
  name = "developers"
}
resource "aws_iam_group" "security" {
  name = "security-team"
}
resource "aws_iam_group" "monitoring" {
  name = "monitoring-team"
}
resource "aws_iam_group" "data" {
  name = "data-team"
}

# Membresías
resource "aws_iam_group_membership" "devops" {
  name  = "devops-team-membership"
  group = aws_iam_group.devops.name
  users = local.devops_users
  depends_on = [aws_iam_user.devops]
}
resource "aws_iam_group_membership" "developers" {
  name  = "developers-membership"
  group = aws_iam_group.developers.name
  users = local.developer_users
  depends_on = [aws_iam_user.developers]
}
resource "aws_iam_group_membership" "security" {
  name  = "security-team-membership"
  group = aws_iam_group.security.name
  users = local.security_users
  depends_on = [aws_iam_user.security]
}
resource "aws_iam_group_membership" "monitoring" {
  name  = "monitoring-team-membership"
  group = aws_iam_group.monitoring.name
  users = local.monitoring_users
  depends_on = [aws_iam_user.monitoring]
}
resource "aws_iam_group_membership" "data" {
  name  = "data-team-membership"
  group = aws_iam_group.data.name
  users = local.data_users
  depends_on = [aws_iam_user.data]
}
