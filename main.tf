##############################################################################
# * Beginner's Guide to Using Terraform on Azure
# 
# This Terraform configuration will create the following:
#
# This will create a Resource group with a virtual network and subnet
# Along with a Windows Server Running IIS.
# All Variables are pulled from Variables.tf

# Configure the Microsoft Azure Provider

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}


provider "azurerm" {
  features {}
}


# Resource Group Resource
resource "azurerm_resource_group" "test_terraform_usnc_rg" {
    name = "${var.resource_group}"
    location = "${var.location}"

    
}

# Azure VNET Resource 
resource "azurerm_virtual_network" "vnet" {
    name = "${var.virtual_network_name}"
    location = "${azurerm_resource_group.test_terraform_usnc_rg.location}"
    address_space = ["${var.address_space}"]
    resource_group_name = "${azurerm_resource_group.test_terraform_usnc_rg.name}"

    
}

# Azure VNET Subnet Resource
resource "azurerm_subnet" "subnet" {
    name = "${var.prefix}subnet"
    virtual_network_name = "${azurerm_virtual_network.vnet.name}"
    resource_group_name = "${azurerm_resource_group.test_terraform_usnc_rg.name}"
    address_prefix = "${var.subnet_prefix}"  
    
}

##############################################################################
# * Build an Windows Server 2016 Datacenter VM
#
# Now that we have a network, we'll deploy an Windows Server 2016.
# An Azure Virtual Machine has several components. In this example we'll build
# a security group, a network interface, a public ip address, a storage 
# account and finally the VM itself. Terraform handles all the dependencies 
# automatically, and each resource is named with user-defined variables.

# Azure NSG Resource, this controls inbound/outbound ACL's on the associated Network Interface
resource "azurerm_network_security_group" "test_terraform_nsg" {
  name = "${var.prefix}-sg"
  location = "${var.location}"
  resource_group_name = "${azurerm_resource_group.test_terraform_usnc_rg.name}"

    security_rule {
    name = "HTTP"
    priority = 100
    direction ="Inbound"
    access = "allow"
    protocol = "tcp"
    source_port_range = "*"
    destination_port_range = "80"
    source_address_prefix = "${var.source_network}"
    destination_address_prefix = "*"
    }

    security_rule {
    name = "RDP"
    priority = 101
    direction = "Inbound"
    access = "allow"
    protocol = "tcp"
    source_port_range = "*"
    destination_port_range = "3389"
    source_address_prefix = "${var.source_network}"
    destination_address_prefix = "*"
    }

    
}


# Network Interface Resource for the Windows VM
resource "azurerm_network_interface" "terraform_test_windowsnic" {
    name = "${var.prefix}terraform_test_windowsnic"
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.test_terraform_usnc_rg.name}"

    ip_configuration {
        name = "terraform_test_windowsnic"
        subnet_id = "${azurerm_subnet.subnet.id}"
        private_ip_address_allocation = "Dynamic"
        
    }

    
}


# Public IP Resource 
resource "azurerm_public_ip" "terraform_test_pip" {
    name = "${var.prefix}-ip"
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.test_terraform_usnc_rg.name}"
    allocation_method = "Dynamic"
    sku = "Standard"
   
}


# Settings for our Windows Virtual Machine
resource "azurerm_virtual_machine" "website" {
    name = "${var.hostname}-site"
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.test_terraform_usnc_rg.name}"
    vm_size = "${var.vm_size}"

    network_interface_ids = ["${azurerm_network_interface.terraform_test_windowsnic.id}"]
    delete_os_disk_on_termination = "true"


    storage_image_reference {
        publisher = "${var.image_publisher}"
        offer = "${var.image_offer}"
        sku = "${var.image_sku}"
        version = "${var.image_version}"
    }

    storage_os_disk {
        name = "${var.hostname}-osdisk"
        managed_disk_type = "Standard_LRS"
        caching = "ReadWrite"
        create_option = "FromImage"
    }

    os_profile {
        computer_name = "${var.hostname}"
        admin_username = "${var.admin_username}"
        admin_password = "${var.admin_password}"
    }

    os_profile_windows_config {
        provision_vm_agent = "true"
        enable_automatic_upgrades = "true"
        timezone = "Central Standard Time"

    }
    
}


resource "azurerm_virtual_machine_extension" "iiswebextension" {
    name = "${var.vm_extension}"
    virtual_machine_id   = azurerm_virtual_machine.website.id
    publisher            = "Microsoft.Powershell"
    type                 = "DSC"
    type_handler_version = "2.20"
    depends_on = ["azurerm_virtual_machine.website"]

    settings = <<SETTINGS
    {
        "configuration" : {
            "url" : "https://usncconfigsinzips.blob.core.windows.net/iis/iiswebservers.zip",
            "script" : "iiswebserver.ps1",
            "function" : "Webserver"
        }
    }
SETTINGS

    

}