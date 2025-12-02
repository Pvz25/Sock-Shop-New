"""
Oracle Cloud ARM Instance Automated Retry Script
Continuously attempts to create an Always Free ARM instance until successful
"""
import time
import sys
from datetime import datetime
import oci
from oci.exceptions import ServiceError

try:
    from colorama import init, Fore, Style
    init(autoreset=True)
    HAS_COLOR = True
except ImportError:
    HAS_COLOR = False
    # Fallback if colorama not installed
    class Fore:
        GREEN = YELLOW = RED = CYAN = MAGENTA = ""
    class Style:
        RESET_ALL = BRIGHT = ""

from oci_config import get_compute_client
from instance_config import INSTANCE_CONFIG, validate_config


class InstanceCreator:
    """Handles Oracle Cloud instance creation with automatic retry logic"""
    
    def __init__(self, retry_interval=60):
        """
        Initialize the instance creator.
        
        Args:
            retry_interval (int): Seconds between retry attempts (default: 60)
        """
        self.retry_interval = retry_interval
        self.attempt_count = 0
        self.compute_client = None
        self.start_time = datetime.now()
    
    def initialize(self):
        """Initialize OCI client and validate configuration"""
        self._print_header()
        
        # Validate configuration
        try:
            validate_config()
        except ValueError as e:
            print(f"\n{Fore.RED}❌ Configuration Error:{Style.RESET_ALL}")
            print(str(e))
            sys.exit(1)
        
        # Initialize compute client
        try:
            self.compute_client = get_compute_client()
            print(f"{Fore.GREEN}✅ OCI client initialized successfully{Style.RESET_ALL}")
        except Exception as e:
            print(f"{Fore.RED}❌ Failed to initialize OCI client: {e}{Style.RESET_ALL}")
            sys.exit(1)
        
        # Display configuration
        self._print_configuration()
    
    def create_instance(self):
        """
        Attempt to create the instance.
        
        Returns:
            tuple: (success: bool, message: str, instance_data: dict or None)
        """
        try:
            print(f"[{self._timestamp()}] {Fore.CYAN}🔄 Attempting to create instance...{Style.RESET_ALL}")
            
            launch_details = oci.core.models.LaunchInstanceDetails(
                **INSTANCE_CONFIG
            )
            
            response = self.compute_client.launch_instance(launch_details)
            instance = response.data
            
            return (
                True,
                f"Instance created successfully: {instance.id}",
                {
                    "id": instance.id,
                    "name": instance.display_name,
                    "state": instance.lifecycle_state,
                    "shape": instance.shape,
                    "region": instance.region
                }
            )
        
        except ServiceError as e:
            # Check if it's a capacity error
            error_msg = str(e)
            if "Out of capacity" in error_msg or "OutOfCapacity" in error_msg or "out of host capacity" in error_msg.lower():
                return (False, "⏳ Out of capacity - will retry", None)
            elif "LimitExceeded" in error_msg:
                return (False, "❌ Free tier limit exceeded - cannot retry", None)
            else:
                return (False, f"❌ API Error: {error_msg}", None)
        
        except Exception as e:
            return (False, f"❌ Unexpected error: {str(e)}", None)
    
    def run(self):
        """Main retry loop"""
        self.initialize()
        
        print(f"\n{Fore.YELLOW}{'=' * 70}{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}🚀 Starting automated retry loop...{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}   Press Ctrl+C to stop{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}{'=' * 70}{Style.RESET_ALL}\n")
        
        try:
            while True:
                self.attempt_count += 1
                
                success, message, instance_data = self.create_instance()
                
                if success:
                    self._print_success(instance_data)
                    break
                else:
                    self._print_retry_status(message)
                    
                    # Check if we should stop (non-capacity errors)
                    if "cannot retry" in message.lower():
                        print(f"\n{Fore.RED}{'=' * 70}{Style.RESET_ALL}")
                        print(f"{Fore.RED}❌ Fatal error - stopping retry loop{Style.RESET_ALL}")
                        print(f"{Fore.RED}{'=' * 70}{Style.RESET_ALL}")
                        sys.exit(1)
                    
                    # Wait before retry
                    print(f"   💤 Waiting {self.retry_interval} seconds before next attempt...\n")
                    time.sleep(self.retry_interval)
        
        except KeyboardInterrupt:
            self._print_interrupted()
            sys.exit(0)
    
    def _timestamp(self):
        """Get formatted timestamp"""
        return datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    def _elapsed_time(self):
        """Get elapsed time since start"""
        elapsed = datetime.now() - self.start_time
        hours, remainder = divmod(int(elapsed.total_seconds()), 3600)
        minutes, seconds = divmod(remainder, 60)
        return f"{hours:02d}:{minutes:02d}:{seconds:02d}"
    
    def _print_header(self):
        """Print startup header"""
        print(f"\n{Fore.MAGENTA}{'=' * 70}{Style.RESET_ALL}")
        print(f"{Fore.MAGENTA}🚀 Oracle Cloud Always Free ARM Instance Creator{Style.RESET_ALL}")
        print(f"{Fore.MAGENTA}   Sock-Shop Application Server - 2 OCPU + 12GB RAM{Style.RESET_ALL}")
        print(f"{Fore.MAGENTA}{'=' * 70}{Style.RESET_ALL}\n")
    
    def _print_configuration(self):
        """Print instance configuration"""
        print(f"\n{Fore.CYAN}📊 Instance Configuration:{Style.RESET_ALL}")
        print(f"   Name: {INSTANCE_CONFIG['display_name']}")
        print(f"   Shape: {INSTANCE_CONFIG['shape']}")
        print(f"   CPU: {INSTANCE_CONFIG['shape_config']['ocpus']} OCPU")
        print(f"   RAM: {INSTANCE_CONFIG['shape_config']['memory_in_gbs']} GB")
        print(f"   Region: ap-hyderabad-1, AD-1")
        print(f"   Retry interval: {self.retry_interval} seconds")
    
    def _print_retry_status(self, message):
        """Print retry attempt status"""
        elapsed = self._elapsed_time()
        print(f"   {Fore.YELLOW}Attempt #{self.attempt_count}{Style.RESET_ALL} [{elapsed}] - {message}")
    
    def _print_success(self, instance_data):
        """Print success message"""
        elapsed = self._elapsed_time()
        print(f"\n{Fore.GREEN}{'=' * 70}{Style.RESET_ALL}")
        print(f"{Fore.GREEN}✅ SUCCESS! Instance created after {self.attempt_count} attempts{Style.RESET_ALL}")
        print(f"{Fore.GREEN}   Total time: {elapsed}{Style.RESET_ALL}")
        print(f"{Fore.GREEN}{'=' * 70}{Style.RESET_ALL}\n")
        print(f"{Fore.CYAN}📋 Instance Details:{Style.RESET_ALL}")
        print(f"   Instance ID: {instance_data['id']}")
        print(f"   Name: {instance_data['name']}")
        print(f"   State: {instance_data['state']}")
        print(f"   Shape: {instance_data['shape']}")
        print(f"   Region: {instance_data['region']}")
        print(f"\n{Fore.GREEN}{'=' * 70}{Style.RESET_ALL}")
        print(f"{Fore.GREEN}🎉 Your Sock-Shop server is being provisioned!{Style.RESET_ALL}")
        print(f"{Fore.GREEN}   Go to Oracle Cloud Console to see your new instance.{Style.RESET_ALL}")
        print(f"{Fore.GREEN}{'=' * 70}{Style.RESET_ALL}\n")
    
    def _print_interrupted(self):
        """Print interruption message"""
        elapsed = self._elapsed_time()
        print(f"\n\n{Fore.YELLOW}{'=' * 70}{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}⏸️  Retry loop interrupted by user{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}   Attempts made: {self.attempt_count}{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}   Total time: {elapsed}{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}{'=' * 70}{Style.RESET_ALL}\n")


def main():
    """Main entry point"""
    # You can change retry_interval here (default: 60 seconds)
    creator = InstanceCreator(retry_interval=60)
    creator.run()


if __name__ == "__main__":
    main()
