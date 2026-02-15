project = "doktori-fe"

public_subnet_id       = "subnet-0a4f71ff33428690d"
private_subnet_id      = "subnet-047324ec024aefc25"
private_route_table_id = "rtb-043cc010d8de82d4d"

bastion_nat_sg_id = "sg-0c20eb6f55e5ca2b9"
nginx_sg_id       = "sg-0bd46908c85ac316c"
fe_sg_id          = "sg-08cda653cbfc67fce"

instance_profile_name = null
fe_instance_profile_name = "doktori-fe-ec2-profile"
instance_type         = "t3.micro"
key_name              = "doktori-fe-key"
fe_app_port           = 3000
