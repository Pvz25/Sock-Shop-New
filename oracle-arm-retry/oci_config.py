"""
OCI Configuration Module
Loads Oracle Cloud Infrastructure credentials from ~/.oci/config
"""
import oci
import os
from pathlib import Path


def get_oci_config():
    """
    Load OCI configuration from default location.
    
    Returns:
        dict: OCI configuration dictionary
    """
    config_path = os.path.join(Path.home(), '.oci', 'config')
    
    if not os.path.exists(config_path):
        raise FileNotFoundError(
            f"OCI config not found at {config_path}. "
            "Please run 'oci setup config' first."
        )
    
    try:
        config = oci.config.from_file()
        # Validate config
        oci.config.validate_config(config)
        return config
    except Exception as e:
        raise Exception(f"Error loading OCI config: {str(e)}")


def get_compute_client():
    """
    Create and return an OCI Compute client.
    
    Returns:
        oci.core.ComputeClient: Initialized compute client
    """
    config = get_oci_config()
    return oci.core.ComputeClient(config)
