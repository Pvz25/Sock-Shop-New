"""
Oracle Cloud Instance Configuration
Defines the exact specifications for the Sock-Shop-app-server instance
"""

# ============================================================================
# IMPORTANT: Replace these OCIDs with YOUR actual values
# Run the commands in SETUP-INSTRUCTIONS.md Phase 3 to get these values
# ============================================================================

# From Step 3.1: Compartment OCID
COMPARTMENT_OCID = "REPLACE_WITH_YOUR_COMPARTMENT_OCID"

# From Step 3.2: Subnet OCID
SUBNET_OCID = "REPLACE_WITH_YOUR_SUBNET_OCID"

# From Step 3.3: Ubuntu 22.04 ARM Image OCID
IMAGE_OCID = "REPLACE_WITH_YOUR_IMAGE_OCID"

# From OCI Console: Your SSH public key content
SSH_PUBLIC_KEY = "REPLACE_WITH_YOUR_SSH_PUBLIC_KEY"

# ============================================================================
# Instance Configuration (Optimized for Sock-Shop: 2 OCPU + 12GB RAM)
# ============================================================================

INSTANCE_CONFIG = {
    # Basic Information
    "display_name": "Sock-Shop-app-server",
    "compartment_id": COMPARTMENT_OCID,
    "availability_domain": "hWFp:AP-HYDERABAD-1-AD-1",
    
    # Shape Configuration (2 OCPU + 12GB RAM - Perfect for Sock-Shop)
    "shape": "VM.Standard.A1.Flex",
    "shape_config": {
        "ocpus": 2.0,
        "memory_in_gbs": 12.0
    },
    
    # Image and Storage
    "source_details": {
        "source_type": "image",
        "image_id": IMAGE_OCID,
        "boot_volume_size_in_gbs": 50
    },
    
    # Networking
    "create_vnic_details": {
        "assign_public_ip": True,
        "subnet_id": SUBNET_OCID,
        "assign_private_dns_record": True
    },
    
    # SSH Key
    "metadata": {
        "ssh_authorized_keys": SSH_PUBLIC_KEY
    }
}


def validate_config():
    """
    Validate that all required OCIDs are configured.
    
    Raises:
        ValueError: If any OCID is not configured
    """
    errors = []
    
    if "REPLACE_WITH" in COMPARTMENT_OCID:
        errors.append("❌ COMPARTMENT_OCID not configured")
    
    if "REPLACE_WITH" in SUBNET_OCID:
        errors.append("❌ SUBNET_OCID not configured")
    
    if "REPLACE_WITH" in IMAGE_OCID:
        errors.append("❌ IMAGE_OCID not configured")
    
    if "REPLACE_WITH" in SSH_PUBLIC_KEY:
        errors.append("❌ SSH_PUBLIC_KEY not configured")
    
    if errors:
        error_msg = "\n".join(errors)
        raise ValueError(
            f"\n{error_msg}\n\n"
            "📋 Action Required:\n"
            "1. Open instance_config.py\n"
            "2. Replace the placeholders with your actual values\n"
            "3. Follow SETUP-INSTRUCTIONS.md Phase 3 to get OCIDs\n"
            "4. Run this script again"
        )
    
    print("✅ Configuration validated successfully")
    return True
