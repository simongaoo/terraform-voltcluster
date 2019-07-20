provider "alicloud" {
   access_key = "" #Alicloud 的访问key pair，可以在Alicloud生成后填入。
	 secret_key = ""
   region = "ap-northeast-1"
}
 
#定义Coordinator 数量
variable "hd_server_cnt" {
  default = "1"
}
 
#定义Worker 数量
variable "hd_node_cnt" {
  default = "2"
}
 
#选择Linux 版本
variable "platform"{
  default = "centos7"
}
 
#定义Coordinator主机名前缀
variable "hd_server_prefix" {
  description = "Prefix to use when naming cluster members"
  default = "node-master"
}
 
#定义Worker主机名前缀
variable "hd_node_prefix" {
  description = "Prefix to use when naming cluster members"
  default = "node-peer"
}
 
#定义Linux root登录密码
variable "password" {
  type = "string"
  default = "!234qwer"
}
 
#Alicloud 服务器区域
variable "availabe_zone" {
  type = "string"
  default = "ap-northeast-1a"
}
 
#Alicloud ECS 硬件配置
data "alicloud_instance_types" "hardware_cfg" {
  cpu_core_count = 4
  memory_size = 16
}
 
#定义VPC Internal IP
resource "alicloud_vpc" "vpc" {
  name       = "voltdb_hd_test"
  cidr_block = "172.16.0.0/12"
}
 
#定义Virtual Switch
resource "alicloud_vswitch" "vsw" {
  vpc_id            = "${alicloud_vpc.vpc.id}"
  cidr_block        = "172.16.0.0/21"
  availability_zone = "${var.availabe_zone}"
}
 
#定义安全组
resource "alicloud_security_group" "default" {
  name = "default"
  vpc_id = "${alicloud_vpc.vpc.id}"
}
 
#定义默认安全访问规则
resource "alicloud_security_group_rule" "allow_all_tcp" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "1/65535"
  priority          = 1
  security_group_id = "${alicloud_security_group.default.id}"
  cidr_ip           = "0.0.0.0/0"
}

#定义将要启动的Coordinator实例的配置
resource "alicloud_instance" "hd_server" {
  count = "${var.hd_server_cnt}" #启动数量
  # ECS 所在区域
  availability_zone = "${var.availabe_zone}"
  security_groups = ["${alicloud_security_group.default.*.id}"]
 
  # ECS 实例的配置
  instance_type        = "${data.alicloud_instance_types.hardware_cfg.instance_types.0.id}"
  system_disk_category = "cloud_efficiency"
  #操作系统版本
  image_id             = "centos_7_04_64_20G_alibase_201701015.vhd"
  #实例和主机名
  instance_name        = "${var.hd_server_prefix}-${count.index}"
  host_name        = "${var.hd_server_prefix}-${count.index}"
  vswitch_id = "${alicloud_vswitch.vsw.id}"
  #可用外部访问的最大带宽（5M）
  internet_max_bandwidth_out = 5
  #登录密码
  password = "${var.password}"
 
}
 
#Coordinator实例启动后执行一系列动作，通过脚本完成安装和配置
resource "null_resource" "configure-ins-ips" {
  count = "${var.hd_server_cnt}"
  connection {
          type     = "ssh"
          user     = "root"
          host = "${element(alicloud_instance.hd_server.*.public_ip, count.index)}"
          password = "${var.password}"
  }
 
  provisioner "file" {
        source = "${path.module}/scripts/${var.platform}/volt-install.sh"
        destination = "~/volt-install.sh"
  }

  provisioner "file" {
        source = "${path.module}/scripts/${var.platform}/base.sh"
        destination = "/tmp/base.sh"
  }

  provisioner "remote-exec" {
        inline = [
            # Adds all cluster members' IP addresses to /etc/hosts (on each member)
            "echo '${join("\n", formatlist("%v", alicloud_instance.hd_server.*.private_ip))}' | awk 'BEGIN{ print \"\\n\\n# Cluster members:\" }; { print $0 \" ${var.hd_server_prefix}-\" NR-1 }' | tee -a /etc/hosts > /dev/null",
            "echo '${join("\n", formatlist("%v", alicloud_instance.hd_node.*.private_ip))}' | awk 'BEGIN{ print \"\\n\\n# Cluster members:\" }; { print $0 \" ${var.hd_node_prefix}-\" NR-1 }' | tee -a /etc/hosts > /dev/null"
            ]
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/base.sh",
      "/tmp/base.sh"
    ]
  }

  provisioner "remote-exec" {
        inline = [
            # Adds all cluster members' IP addresses to /etc/hosts (on each member)
            "chmod +x ~/volt-install.sh",
            "~/volt-install.sh ${join(" ", formatlist("%v", alicloud_instance.hd_server.*.host_name))}",
            "/opt/voltdb/bin/voltdb start --http=8090 --dir=/opt --host=${join(",", formatlist("%v", alicloud_instance.hd_server.*.host_name))},${join(",", formatlist("%v", alicloud_instance.hd_node.*.host_name))} -B >/dev/null",
            
        ]
  }
 
}

#定义将要启动的Worker实例的配置
resource "alicloud_instance" "hd_node" {
  count = "${var.hd_node_cnt}"
  
  availability_zone = "${var.availabe_zone}"
  security_groups = ["${alicloud_security_group.default.*.id}"]
 
  
  instance_type        = "${data.alicloud_instance_types.hardware_cfg.instance_types.0.id}"
  system_disk_category = "cloud_efficiency"
  image_id             = "centos_7_04_64_20G_alibase_201701015.vhd"
  instance_name        = "${var.hd_node_prefix}-${count.index}"
  host_name        = "${var.hd_node_prefix}-${count.index}"
  vswitch_id = "${alicloud_vswitch.vsw.id}"
  internet_max_bandwidth_out = 5
  password = "${var.password}"
 
}
 
#Worker实例启动后执行一系列动作，通过脚本完成安装和配置
resource "null_resource" "configure-ins2-ips" {
  count = "${var.hd_node_cnt}"
 
  connection {
          type     = "ssh"
          user     = "root"
          host = "${element(alicloud_instance.hd_node.*.public_ip, count.index)}"
          password = "${var.password}"
  }
 
  provisioner "file" {
        source = "${path.module}/scripts/${var.platform}/volt-install.sh"
        destination = "~/volt-install.sh"
  }

  provisioner "file" {
        source = "${path.module}/scripts/${var.platform}/base.sh"
        destination = "/tmp/base.sh"
  }
  
  provisioner "remote-exec" {
        inline = [
            # Adds all cluster members' IP addresses to /etc/hosts (on each member)
            "echo '${join("\n", formatlist("%v", alicloud_instance.hd_server.*.private_ip))}' | awk 'BEGIN{ print \"\\n\\n# Cluster members:\" }; { print $0 \" ${var.hd_server_prefix}-\" NR-1 }' | tee -a /etc/hosts > /dev/null",
            "echo '${join("\n", formatlist("%v", alicloud_instance.hd_node.*.private_ip))}' | awk 'BEGIN{ print \"\\n\\n# Cluster members:\" }; { print $0 \" ${var.hd_node_prefix}-\" NR-1 }' | tee -a /etc/hosts > /dev/null"
            ]
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/base.sh",
      "/tmp/base.sh"
    ]
  }
  
  provisioner "remote-exec" {
        inline = [
            # Adds all cluster members' IP addresses to /etc/hosts (on each member)
            "chmod +x ~/volt-install.sh",
            "~/volt-install.sh ${join(" ", formatlist("%v", alicloud_instance.hd_server.*.host_name))}",
            "/opt/voltdb/bin/voltdb start --http=8090 --dir=/opt --host=${join(",", formatlist("%v", alicloud_instance.hd_server.*.host_name))},${join(",", formatlist("%v", alicloud_instance.hd_node.*.host_name))} -B >/dev/null",
           
        ]
  } 
}
 
 
#Terraform 执行后的打印内容，这里输出Public IP of ECS Instances，就用通过SSH登录 
output "hd_master_address" {
  value = "${alicloud_instance.hd_server.*.public_ip}"
}
 
output "hd_peer_address" {
  value = "${alicloud_instance.hd_node.*.public_ip}"
}