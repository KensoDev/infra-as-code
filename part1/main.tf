provider "aws" {
  region  = "${var.aws_region}"
  profile = "avi"
}

resource "aws_vpc" "production" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "production" {
  vpc_id = "${aws_vpc.production.id}"
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.production.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.production.id}"
}

resource "aws_subnet" "production-1a" {
  availability_zone       = "us-east-1a"
  vpc_id                  = "${aws_vpc.production.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "production-1d" {
  availability_zone       = "us-east-1d"
  vpc_id                  = "${aws_vpc.production.id}"
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "production-1c" {
  availability_zone       = "us-east-1c"
  vpc_id                  = "${aws_vpc.production.id}"
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
}

resource "aws_elb" "web" {
  name            = "web-production"

  subnets         = ["${aws_subnet.production-1a.id}", "${aws_subnet.production-1c.id}", "${aws_subnet.production-1d.id}"]
  security_groups = ["${aws_security_group.elb.id}"]
  instances       = ["${aws_instance.prod-web.id}"]

  tags {
    Name = "prod-web-elb"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 20
    target              = "HTTP:80/"
    interval            = 30
  }

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}
resource "aws_security_group" "internal" {
  name        = "internal"
  description = "Internal Connections"
  vpc_id      = "${aws_vpc.production.id}"

  tags {
    Name = "Internal Security Group"
  }

  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "elb" {
  name        = "elb"
  description = "Load Balancer Security Group"
  vpc_id      = "${aws_vpc.production.id}"

  tags {
    Name = "Load balancer security group"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "external" {
  name        = "external"
  description = "Connection From the world"
  vpc_id      = "${aws_vpc.production.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_IP_HERE/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "auth" {
  key_name = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

resource "template_file" "web_userdata" {
  template = "${file("web_userdata.tpl")}"

  vars {
    domain_name = "yourdomain"
  }
}

resource "aws_instance" "prod-web" {
  count     = 1
  user_data = "${template_file.web_userdata.rendered}"

  connection {
    user = "ubuntu"
  }

  tags {
    Name = "prod-web-${count.index + 1}"
  }

  instance_type          = "m3.xlarge"

  key_name               = "${aws_key_pair.auth.id}"
  ami                    = "${lookup(var.aws_amis, var.aws_region)}"

  vpc_security_group_ids = ["${aws_security_group.external.id}", "${aws_security_group.internal.id}"]
  subnet_id              = "${aws_subnet.production-1a.id}"
}
