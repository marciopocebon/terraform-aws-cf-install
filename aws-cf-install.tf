provider "aws" {
	access_key = "${var.aws_access_key}"
	secret_key = "${var.aws_secret_key}"
	region = "${var.aws_region}"
}

resource "aws_vpc" "default" {
	cidr_block = "${var.network}.0.0/16"
	enable_dns_hostnames = "true"
	tags {
		Name = "${var.aws_vpc_name}"
	}
}

output "aws_vpc_id" {
	value = "${aws_vpc.default.id}"
}

resource "aws_internet_gateway" "default" {
	vpc_id = "${aws_vpc.default.id}"
}

output "aws_internet_gateway_id" {
	value = "${aws_internet_gateway.default.id}"
}

resource "aws_subnet" "bastion" {
	vpc_id = "${aws_vpc.default.id}"
	cidr_block = "${var.network}.0.0/24"
	tags {
		Name = "${var.aws_vpc_name}-bastion"
	}
}

output "aws_subnet_bastion_id" {
	value = "${aws_subnet.bastion.id}"
}

resource "aws_subnet" "bosh" {
	vpc_id = "${aws_vpc.default.id}"
	cidr_block = "${var.network}.1.0/24"
	availability_zone = "${lookup(var.cf1_az, var.aws_region)}"
	tags {
		Name = "${var.aws_vpc_name}-bosh"
	}
}

output "aws_subnet_bosh_id" {
  value = "${aws_subnet.bosh.id}"
}

output "aws_subnet_bosh_prefix" {
  value = "${var.network}.1"
}

resource "aws_subnet" "cfruntime-2a" {
	vpc_id = "${aws_vpc.default.id}"
	cidr_block = "${var.network}.3.0/24"
	tags {
		Name = "cf1"
	}
}

output "aws_subnet_cfruntime-2a_id" {
  value = "${aws_subnet.cfruntime-2a.id}"
}

resource "aws_route_table" "public" {
	vpc_id = "${aws_vpc.default.id}"

	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = "${aws_internet_gateway.default.id}"
	}
}

output "aws_route_table_public_id" {
	value = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "bastion-public" {
	subnet_id = "${aws_subnet.bastion.id}"
	route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "bosh-public" {
	subnet_id = "${aws_subnet.bosh.id}"
	route_table_id = "${aws_route_table.public.id}"
}

resource "aws_security_group" "bastion" {
	name = "bastion"
	description = "Allow SSH traffic from the internet"
	vpc_id = "${aws_vpc.default.id}"

	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	ingress {
		from_port = 0
		to_port = 65535
		protocol = "tcp"
		self = "true"
	}

	ingress {
		from_port = 0
		to_port = 65535
		protocol = "udp"
		self = "true"
	}

	ingress {
		cidr_blocks = ["0.0.0.0/0"]
		from_port = -1
		to_port = -1
		protocol = "icmp"
	}

	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

	tags {
		Name = "${var.aws_vpc_name}-bastion"
	}

}

output "aws_security_group_bastion_id" {
  value = "${aws_security_group.bastion.id}"
}


resource "aws_security_group" "bosh" {
	name = "bosh"
	vpc_id = "${aws_vpc.default.id}"

	ingress {
		from_port = 0 
		to_port = 0
		protocol = "-1"
		self = "true"
	}

	ingress {
		cidr_blocks = ["0.0.0.0/0"]
		from_port = -1
		to_port = -1
		protocol = "icmp"
	}

	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["${aws_instance.bastion.public_ip}/32"]
	}

	ingress {
		cidr_blocks = ["${aws_instance.bastion.public_ip}/32"]
		from_port = 6868 
		to_port = 6868
		protocol = "tcp"
	}

	ingress {
		cidr_blocks = ["${aws_instance.bastion.public_ip}/32"]
		from_port = 25555 
		to_port = 25555
		protocol = "tcp"
	}

	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

	tags {
		Name = "${var.aws_vpc_name}-bosh"
	}

}

output "aws_security_group_bosh_id" {
  value = "${aws_security_group.bosh.id}"
}

output "aws_security_group_bosh_name" {
  value = "${aws_security_group.bosh.name}"
}

resource "aws_security_group" "cf" {
	name = "cf-${var.network}-${aws_vpc.default.id}"
	description = "CF security groups"
	vpc_id = "${aws_vpc.default.id}"

	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	ingress {
		from_port = 80
		to_port = 80
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	ingress {
		from_port = 443
		to_port = 443
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	ingress {
		cidr_blocks = ["0.0.0.0/0"]
		from_port = 4443
		to_port = 4443
		protocol = "tcp"
	}

	ingress {
		cidr_blocks = ["0.0.0.0/0"]
		from_port = 4222
		to_port = 25777
		protocol = "tcp"
	}

	ingress {
		cidr_blocks = ["0.0.0.0/0"]
		from_port = -1
		to_port = -1
		protocol = "icmp"
	}

	ingress {
		from_port = 0
		to_port = 65535
		protocol = "tcp"
		self = "true"
	}

	ingress {
		from_port = 0
		to_port = 65535
		protocol = "udp"
		self = "true"
	}

	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

	tags {
		Name = "cf-${var.network}-${aws_vpc.default.id}"
	}

}

output "aws_security_group_cf_name" {
  value = "${aws_security_group.cf.name}"
}

output "aws_security_group_cf_id" {
  value = "${aws_security_group.cf.id}"
}


resource "aws_eip" "cf" {
	vpc = true
}

output "aws_eip_cf_public_ip" {
  value = "${aws_eip.cf.public_ip}"
}


resource "aws_eip" "bosh_ip" {
	vpc = true
}

output "aws_eip_bosh_ip" {
  value = "${aws_eip.bosh_ip.public_ip}"
}

resource "aws_instance" "bastion" {
  ami = "${lookup(var.aws_ubuntu_ami, var.aws_region)}"
  instance_type = "m3.medium"
  key_name = "${var.aws_key_name}"
  associate_public_ip_address = true
  security_groups = ["${aws_security_group.bastion.id}"]
  subnet_id = "${aws_subnet.bastion.id}"
  ebs_block_device {
    device_name = "xvdc"
    volume_size = "40"
  }

  tags {
   Name = "bastion"
  }

}

output "bastion_ip" {
  value = "${aws_instance.bastion.public_ip}"
}


output "cf_admin_pass" {
  value = "${var.cf_admin_pass}"
}

output "aws_key_path" {
  value = "${var.aws_key_path}"
}

output "aws_key_name" {
  value = "${var.aws_key_name}"
}

output "cf_api" {
	value = "api.run.${aws_eip.cf.public_ip}.xip.io"
}

output "aws_access_key" {
	value = "${var.aws_access_key}"
}

output "aws_secret_key" {
	value = "${var.aws_secret_key}"
}

output "aws_region" {
	value = "${var.aws_region}"
}

output "aws_az" {
	value = "${lookup(var.cf1_az, var.aws_region)}"
}

output "ipmask" {
	value = "${var.network}"
}


