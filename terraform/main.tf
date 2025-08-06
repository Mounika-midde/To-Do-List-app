#vpc
resource "aws_vpc" "my-vpc-todo" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "my-vpc-todo"
  }
}

#internet gateway 
resource "aws_internet_gateway" "todo-igw" {
  vpc_id = aws_vpc.my-vpc-todo.id
  tags = {
    Name = "todo-igw"
  }
}

#public subnets
resource "aws_subnet" "todo-public-1" {
  vpc_id                  = aws_vpc.my-vpc-todo.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

}

resource "aws_subnet" "todo-public-2" {
  vpc_id            = aws_vpc.my-vpc-todo.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

}

#private subnets 
resource "aws_subnet" "todo-private-ecs" {
  vpc_id            = aws_vpc.my-vpc-todo.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-south-1a"
}

resource "aws_subnet" "todo-private-rds1" {
  vpc_id            = aws_vpc.my-vpc-todo.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-south-1a"

}

resource "aws_subnet" "todo-private-rds2" {
  vpc_id            = aws_vpc.my-vpc-todo.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "ap-south-1b"
}

#route table for public sunbent
resource "aws_route_table" "route-public-todo" {
  vpc_id = aws_vpc.my-vpc-todo.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.todo-igw.id

  }
}

resource "aws_route_table_association" "public-1" {
  subnet_id      = aws_subnet.todo-public-1.id
  route_table_id = aws_route_table.route-public-todo.id

}

resource "aws_route_table_association" "public-2" {
  subnet_id      = aws_subnet.todo-public-2.id
  route_table_id = aws_route_table.route-public-todo.id

}

#NAT gateway 
resource "aws_eip" "NAT" {
  vpc = true
}

resource "aws_nat_gateway" "todo-NAT" {
  allocation_id = aws_eip.NAT.id
  subnet_id     = aws_subnet.todo-public-1.id

}

#route table for private subnets 
resource "aws_route_table" "route-private-todo" {
  vpc_id = aws_vpc.my-vpc-todo.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.todo-NAT.id
  }
}

resource "aws_route_table_association" "private-ecs" {
  subnet_id      = aws_subnet.todo-private-ecs.id
  route_table_id = aws_route_table.route-private-todo.id

}

resource "aws_route_table_association" "private-rds1" {
  subnet_id      = aws_subnet.todo-private-rds1.id
  route_table_id = aws_route_table.route-private-todo.id
}
resource "aws_route_table_association" "private-rds2" {
  subnet_id      = aws_subnet.todo-private-rds2.id
  route_table_id = aws_route_table.route-private-todo.id

}

# security group for ALB
resource "aws_security_group" "alb-sg" {
  name   = "alb-sg"
  vpc_id = aws_vpc.my-vpc-todo.id


  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#security group for ecs
resource "aws_security_group" "ecs-sg" {
  name   = "ecs-sg"
  vpc_id = aws_vpc.my-vpc-todo.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb-sg.id]
  }
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb-sg.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "tcp"
    security_groups = [aws_security_group.alb-sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

}

resource "aws_security_group" "rds_sg" {
  name   = "rds-sg"
  vpc_id = aws_vpc.my-vpc-todo.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs-sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#ALB
resource "aws_lb" "todo-lb" {
  name               = "todo-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets            = [aws_subnet.todo-public-1.id, aws_subnet.todo-public-2.id]
}


resource "aws_lb_target_group" "frontend-tg" {
  name     = "frontend-tg"
  target_type = "ip"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my-vpc-todo.id


  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_target_group" "backend-tg" {
  name     = "backend-tg"
  port     = 8080
  target_type = "ip"
  protocol = "HTTP"
  vpc_id   = aws_vpc.my-vpc-todo.id

  health_check {
    path                = "/api/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.todo-lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.frontend-tg.arn
  }
}
resource "aws_lb_listener_rule" "backend" {
  listener_arn = aws_lb_listener.frontend.arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.backend-tg.arn
    
  }
  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# --- ECR Repository  for frontend---
resource "aws_ecr_repository" "ecr-repo-frontend" {
  name = "ecr-repo-frontend"
}

#ecr repo for backend
resource "aws_ecr_repository" "ecr-repo-backend" {
  name = "ecr-repo-backend"
}

#ecs
resource "aws_ecs_cluster" "todo-cluster" {
  name = "todo-cluster"
}

#iam role
resource "aws_iam_role" "ecs_task_execution_role" {
    name = "ecs-task-excution-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement =[{
            Effect = "Allow",
            Principal ={
                Service = "ecs-tasks.amazonaws.com"
            },
            Action = "sts:AssumeRole"
        }]
    })
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_policy" {
  role =  aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#task definition for frontend 
resource "aws_ecs_task_definition" "frontend_task" {
    family      = "frontend-task"
    requires_compatibilities = ["FARGATE"]
    network_mode =  "awsvpc"
    cpu  = "256"
    memory = "512"
    execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

    container_definitions = jsonencode([
          {
      name      = "frontend"
      image     = "${aws_ecr_repository.ecr-repo-frontend.repository_url}"
      portMappings = [{
        containerPort = 80
        hostPort      = 80
        protocol      = "tcp"
      }]
    }
    ])
}

#task definition for backend
resource "aws_ecs_task_definition" "backend_task" {
  family                   = "backend-task"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = "256"
  memory                  = "512"
  execution_role_arn      = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${aws_ecr_repository.ecr-repo-backend.repository_url}"
      portMappings = [{
        containerPort = 8080
        hostPort      = 8080
        protocol      = "tcp"
      }]
      environment = [
        {
          name  = "DB_NAME"
          value = "todo"
        },
        {
          name  = "DB_USER"
          value = aws_db_instance.todo_db.username
        },
        {
          name  = "DB_PASS"
          value = aws_db_instance.todo_db.password
        },
        {
          name  = "DB_HOST"
          value = aws_db_instance.todo_db.address
        },
        {
          name = "FRONTEND_URL"
          value = "http://${aws_lb.todo-lb.dns_name}"
        }
      ]
    }
  ])
}

#ECS service for frontend
resource "aws_ecs_service" "frontend_service" {
    name   = "frontend-service"
    cluster = aws_ecs_cluster.todo-cluster.id
    task_definition = aws_ecs_task_definition.frontend_task.arn
    desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.todo-private-ecs.id]
    assign_public_ip = false
    security_groups = [aws_security_group.ecs-sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend-tg.arn
    container_name   = "frontend"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.frontend]
}
  

 #ECS serivce for backend 
resource "aws_ecs_service" "backend_service" {
  name            = "backend-service"
  cluster         = aws_ecs_cluster.todo-cluster.id
  task_definition = aws_ecs_task_definition.backend_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.todo-private-ecs.id]
    assign_public_ip = false
    security_groups = [aws_security_group.ecs-sg.id]
  }
load_balancer {
    target_group_arn = aws_lb_target_group.backend-tg.arn
    container_name   = "backend"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.frontend]
}

#rds mysql
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.todo-private-rds1.id, aws_subnet.todo-private-rds2.id]
}

resource "aws_db_instance" "todo_db" {
  identifier          = "todo-rds"
  allocated_storage   = 20
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.t3.micro"
  name                = "todo"
  username            = "admin"
  password            = "mounika11"
  publicly_accessible = false
  multi_az            = false
  storage_encrypted   = true
  skip_final_snapshot = true

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}
