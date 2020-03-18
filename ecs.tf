resource "aws_security_group" "ecs_etherpad" {
  name   = "ecs_etherpad"
  vpc_id = data.aws_vpc.main.id
  ingress {
    from_port   = 9001
    to_port     = 9001
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/8"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_iam_policy_document" "ecs_assumerole" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_tasks_assumerole" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com","ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_role" {
  statement {
    effect  = "Allow"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams", "ecs:*", "elasticloadbalancing:*"]
    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:etherpad:log-stream:*",
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:etherpad:*",
      "arn:aws:elasticloadbalancing:*"
    ]
  }
}

resource "aws_iam_policy" "ecs" {
  name        = "ecs"
  path        = "/"
  description = "ECS policy"
  policy      = data.aws_iam_policy_document.ecs_role.json
}

resource "aws_iam_role" "ecs" {
  name                 = "ECS"
  description          = "Role for ECS cluster"
  max_session_duration = 43200
  assume_role_policy   = data.aws_iam_policy_document.ecs_assumerole.json
}

resource "aws_iam_role_policy_attachment" "ecs" {
  policy_arn = aws_iam_policy.ecs.arn
  role       = aws_iam_role.ecs.name
}

resource "aws_cloudwatch_log_group" "etherpad" {
  name              = "etherpad"
  retention_in_days = 1
}

resource "aws_ecs_cluster" "etherpad" {
  name               = "etherpad"
  capacity_providers = toset(["FARGATE","FARGATE_SPOT"])
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 100
  }
}

resource "aws_ecs_service" "etherpad" {
  name            = "etherpad"
  cluster         = "${aws_ecs_cluster.etherpad.id}"
  task_definition = "${aws_ecs_task_definition.etherpad.arn}"
  desired_count   = 1
  depends_on      = ["aws_iam_role_policy_attachment.ecs"]
  network_configuration {
    subnets         = data.aws_subnet_ids.private.ids
    security_groups = [aws_security_group.ecs_etherpad.id]
  }
 
  load_balancer {
    target_group_arn = aws_lb_target_group.etherpad.arn
    container_name   = "etherpad"
    container_port   = 9001
  }

  capacity_provider_strategy {
    base              = 0 
    capacity_provider = "FARGATE" 
    weight            = 100 
  }
}

data "template_file" "etherpad_tasks" {
  template = file("${path.module}/files/etherpad-tasks.json")
}

resource "aws_ecs_task_definition" "etherpad" {
  family                   = "etherpad"
  container_definitions    = data.template_file.etherpad_tasks.rendered
  network_mode             = "awsvpc"
  requires_compatibilities = toset(["FARGATE"])
  cpu                      = 1024
  memory                   = 2048
}
