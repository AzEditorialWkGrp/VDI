data "http" "myip" {
  url = "https://ipinfo.io/ip"
}

resource "azurerm_virtual_network" "vdi_virtual_network" {
  name                = "vnet-${var.base_name}-${var.deployment_index}"
  location            = var.location
  address_space       = ["10.0.0.0/16"]
  resource_group_name = var.resource_group_name
  dns_servers         = ["10.0.1.4", "168.63.129.16"]
}

resource "azurerm_subnet" "dc" {
  name                 = "snet-${var.base_name}-dc-${var.deployment_index}"
  address_prefix       = var.dc_subnet_cidr
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vdi_virtual_network.name
}

resource "azurerm_subnet" "cac" {
  name                 = "snet-${var.base_name}-cac-${var.deployment_index}"
  address_prefix       = var.cac_subnet_cidr
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vdi_virtual_network.name
  depends_on           = [azurerm_subnet.dc]
}

resource "azurerm_subnet" "workstation" {
  name                 = "snet-${var.base_name}-workstation-${var.deployment_index}"
  address_prefix       = var.ws_subnet_cidr
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vdi_virtual_network.name
  depends_on           = [azurerm_subnet.cac]
}

resource "azurerm_public_ip" "dc_ip" {
  name                    = "pip-${var.dc_virtual_machine_name}-${var.deployment_index}"
  location                = var.location
  resource_group_name     = var.resource_group_name
  allocation_method       = "Static"
  idle_timeout_in_minutes = 30
}

resource "azurerm_public_ip" "cac" {
  name                    = "pip-${var.cac_virtual_machine_name}-${var.deployment_index}"
  location                = var.location
  resource_group_name     = var.resource_group_name
  allocation_method       = "Static"
  idle_timeout_in_minutes = 30
}

resource "azurerm_public_ip" "nat" {
  name                    = "pip-nat-${var.deployment_index}"
  location                = var.location
  resource_group_name     = var.resource_group_name
  allocation_method       = "Static"
  sku                     = "Standard"
  idle_timeout_in_minutes = 30
}

resource "azurerm_public_ip_prefix" "nat" {
  name                = "nat-gateway-PIPP"
  location            = var.location
  resource_group_name = var.resource_group_name
  prefix_length       = 30
}

resource "azurerm_nat_gateway" "nat" {
  name                    = "nat-gateway"
  location                = var.location
  resource_group_name     = var.resource_group_name
  public_ip_address_ids   = [azurerm_public_ip.nat.id]
  public_ip_prefix_ids    = [azurerm_public_ip_prefix.nat.id]
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

resource "null_resource" "delay_nat_gateway_association" {
  provisioner "local-exec" {
    command = "sleep 1 || powershell sleep 1"
  }

  triggers = {
    "before" = "${azurerm_nat_gateway.nat.id}"
  }
}

resource "azurerm_subnet_nat_gateway_association" "nat" {
  subnet_id      = azurerm_subnet.workstation.id
  nat_gateway_id = azurerm_nat_gateway.nat.id
  depends_on     = [null_resource.delay_nat_gateway_association]
}

resource "azurerm_network_interface" "dc_nic" {
  name                = "nic-${var.deployment_index}-${var.dc_virtual_machine_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  ip_configuration {
    name                          = "primary"
    private_ip_address_allocation = "Static"
    private_ip_address            = var.dc_private_ip
    public_ip_address_id          = azurerm_public_ip.dc_ip.id
    subnet_id                     = azurerm_subnet.dc.id
  }
}

resource "null_resource" "delay_nic_dc" {
  provisioner "local-exec" {
    command = "sleep 1 || powershell sleep 1"
  }

  triggers = {
    "before" = "${azurerm_network_interface.dc_nic.id}"
  }
}

resource "azurerm_network_interface" "cac" {
  name                = "nic-${var.deployment_index}-${var.cac_virtual_machine_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  ip_configuration {
    name                          = "primary"
    private_ip_address_allocation = "Static"
    private_ip_address            = var.cac_private_ip
    public_ip_address_id          = azurerm_public_ip.cac.id
    subnet_id                     = azurerm_subnet.cac.id
  }
  depends_on = [null_resource.delay_nic_dc]
}

resource "azurerm_private_dns_zone" "dns" {
  name                = "dns.internal"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "cac" {
  name                  = "dns-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.dns.name
  virtual_network_id    = azurerm_virtual_network.vdi_virtual_network.id
}

resource "azurerm_private_dns_a_record" "dns" {
  name                = var.active_directory_netbios_name
  zone_name           = azurerm_private_dns_zone.dns.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = ["10.0.1.4"]
}

resource "azurerm_private_dns_srv_record" "dns-cac" {
  name                = "_ldap._tcp.${var.active_directory_netbios_name}"
  zone_name           = azurerm_private_dns_zone.dns.name
  resource_group_name = var.resource_group_name
  ttl                 = 300

  record {
    priority = 1
    weight   = 1
    port     = 389
    target   = "${var.active_directory_netbios_name}.dns.internal"
  }
}

resource "azurerm_private_dns_srv_record" "dns-ldaps" {
  name                = "_ldap._tcp.vm-vdi-dc${var.deployment_index}.${var.active_directory_netbios_name}"
  zone_name           = azurerm_private_dns_zone.dns.name
  resource_group_name = var.resource_group_name
  ttl                 = 300

  record {
    priority = 3
    weight   = 3
    port     = 389
    target   = "${var.active_directory_netbios_name}.dns.internal"
  }
}

resource "azurerm_private_dns_srv_record" "dns-win" {
  name                = "_ldap._tcp.dc._msdcs.${var.active_directory_netbios_name}"
  zone_name           = azurerm_private_dns_zone.dns.name
  resource_group_name = var.resource_group_name
  ttl                 = 300

  record {
    priority = 2
    weight   = 2
    port     = 389
    target   = "${var.active_directory_netbios_name}.dns.internal"
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.base_name}-${var.deployment_index}"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowAllVnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["1-65525"]
    source_address_prefix      = "10.0.0.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowWinRM"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "tcp"
    source_port_range          = "*"
    destination_port_range     = "5986"
    source_address_prefix      = chomp(data.http.myip.body)
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = chomp(data.http.myip.body)
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowRDP"
    priority                   = 500
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = chomp(data.http.myip.body)
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowPCoIP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "4172"]
    source_address_prefix      = var.allowed_client_cidrs
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "cac" {
  subnet_id                 = azurerm_subnet.cac.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "null_resource" "delay_nsg_association_dc" {
  provisioner "local-exec" {
    command = "sleep 1 || powershell sleep 1"
  }

  triggers = {
    "before" = "${azurerm_subnet_network_security_group_association.cac.id}"
  }
}

resource "azurerm_subnet_network_security_group_association" "dc" {
  subnet_id                 = azurerm_subnet.dc.id
  network_security_group_id = azurerm_network_security_group.nsg.id
  depends_on                = [null_resource.delay_nsg_association_dc]
}

resource "null_resource" "delay_nsg_association_workstation" {
  provisioner "local-exec" {
    command = "sleep 1 || powershell sleep 1"
  }

  triggers = {
    "before" = azurerm_subnet_network_security_group_association.dc.id
  }
}

resource "azurerm_subnet_network_security_group_association" "workstation" {
  subnet_id                 = azurerm_subnet.workstation.id
  network_security_group_id = azurerm_network_security_group.nsg.id
  depends_on                = [null_resource.delay_nsg_association_workstation]
}