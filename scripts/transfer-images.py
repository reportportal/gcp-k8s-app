import yaml
import subprocess
import argparse

# Create the parser
parser = argparse.ArgumentParser(description="Script for transferring used chart images from Docker Hub to GCR")

# Add the arguments
parser.add_argument('--values-path', type=str, required=True, help='Path to the chart values.yaml file')
parser.add_argument('--primary-service', type=str, required=False, default='', help='Primary image service')
parser.add_argument('--old-repo', type=str, required=False, default='reportportal', help='Old repository')
parser.add_argument('--new-registry', type=str, required=False, default='gcr.io', help='New registry')
parser.add_argument('--new-repo', type=str, required=False, default='epam-mp-rp/reportportal', help='New repository with registry')

# Parse the arguments
args = parser.parse_args()

# Define the new registry
values_file_path = args.values_path
primary_image_service = args.primary_service
old_repo = args.old_repo
new_registry = args.new_registry
new_repo = args.new_repo

# Load the values.yaml file
with open(values_file_path, 'r') as file:
    values = yaml.safe_load(file)

# Iterate over the services
for key, value in values.items():
    # Get the repository and tag
    if isinstance(value, dict) and 'repository' in value:
        repository = value['repository']
        tag = value['tag']

        # Construct the old and new image names
        if key == primary_image_service:
            old_image = f'{repository}:{tag}'
            new_image = f'{new_registry}/{new_repo}:{tag}'
        else:
            old_image = f'{repository}:{tag}'
            new_image = old_image.replace(f'{old_repo}/', f'{new_registry}/{new_repo}/reportportal-')

        # Pull the old image, tag it with the new image name, and push it to the new registry
        result = subprocess.run(['docker', 'manifest', 'inspect', new_image], capture_output=True, text=True)
        if 'no such manifest' in result.stderr:
            print(f'Key: {key}\nOld_image: {old_image}\nNew_image: {new_image}')
            subprocess.run(['docker', 'pull', old_image])
            subprocess.run(['docker', 'tag', old_image, new_image])
            subprocess.run(['docker', 'push', new_image])
            print(f'key: {key}\nImage: {new_image} pushed to {new_registry}\n')
        elif result.returncode == 0:
            print(f'key: {key}\nImage: {new_image} already exists\n')
        else:
            print(f'key: {key}\nError: {result.stderr}\n')