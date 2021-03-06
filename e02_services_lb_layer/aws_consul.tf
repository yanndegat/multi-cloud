resource "aws_instance" "consul" {
  count = 3
  instance_type = "${var.aws_instance_type}"
  ami = "${var.aws_image}"
  key_name = "${var.keypair}"
  // iam_instance_profile = "${aws_iam_instance_profile.consul.id}"
  iam_instance_profile = "ec2_describe_instances"

  vpc_security_group_ids = ["${aws_security_group.consul_servers.id}"]
  subnet_id = "${element(data.terraform_remote_state.network.aws_priv_subnet, count.index)}"
  associate_public_ip_address = false

  user_data = "${data.template_file.aws_bootstrap_consul.rendered}"

  tags {
    Name = "server-aws-consul-${count.index + 1}"
    Consul = "server"
  }

  depends_on = ["google_compute_instance.consul"]
}

data "template_file" "aws_bootstrap_consul" {
  template = "${file("bootstrap_consul.tpl")}"

  vars {
    zone = "$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone)"
    datacenter = "$(echo $${ZONE} | sed 's/.$//')"
    output_ip = "$(curl http://169.254.169.254/latest/meta-data/local-ipv4)"
    consul_version = "0.9.2"
    join = "\"retry_join\": [\"provider=aws tag_key=Consul tag_value=server\"], \"retry_join_wan\": [${join(", ", formatlist("\"%s\"", google_compute_instance.consul.*.network_interface.0.address))}]"
  }
}
